#include "protocol.h"

#include <numeric>
#include <vector>

#include "contourklip.hpp"
#include "json.hpp"

using json = nlohmann::json;


static auto get_args(std::vector<std::int32_t> sizes)
{
  auto total = std::accumulate(sizes.begin(), sizes.end(), 0U);

  std::vector<uint8_t> buffer;
  buffer.resize(total);
  wasm_minimal_protocol_write_args_to_buffer(buffer.data());

  size_t offset = 0;
  std::vector<json> args;
  for (auto length : sizes) {
    args.push_back(json::from_cbor(buffer.data() + offset,
                                   buffer.data() + offset + length));
    offset += length;
  }
  return args;
}

EMSCRIPTEN_KEEPALIVE
extern "C" std::int32_t clip_path(std::int32_t source_len,
                                  std::int32_t mask_len,
                                  std::int32_t mode_len)
{
  auto args = get_args({source_len, mask_len, mode_len});

  auto to_pt = [](const json& j) {
    return contourklip::Point2d{j[0], j[1]};
  };

  auto to_contour = [&to_pt](const json& j) -> contourklip::Contour {
    if (j.empty() || j[0].size() < 2) {
      return {};
    }

    contourklip::Point2d last = to_pt(j[0][1]);
    contourklip::Contour c(last);

    for (const auto& s : j) {
      auto is_line = s[0] == "line";
      if (is_line) {
        for (auto i = 2; i < s.size(); ++i) {
          auto pt = to_pt(s[i]);
          if (pt != last)
            c.push_back(to_pt(s[i]));
          last = pt;
        }
      } else {
        auto start = to_pt(s[1]);
        auto end = to_pt(s[2]);
        if (start != last)
          c.push_back(start);
        c.push_back(to_pt(s[3]), to_pt(s[4]), end);
        last = end;
      }
    }

    c.close();
    return c;
  };

  auto to_path = [](const contourklip::Contour& c) {
    auto p = json::array();

    // Current line to append points to
    json* line = nullptr;

    // Last point
    contourklip::Point2d last;

    for (const auto& s : c) {
      switch (s.segment_shape()) {
      case contourklip::LINE:
        if (!line) {
          p.push_back(json::array());
          line = &p.back();
          line->push_back("line");
        }
        line->push_back({ s.point().x(), s.point().y(), 0 });
        break;

      case contourklip::CUBIC_BEZIER:
        if (line) {
          line = nullptr;
        }
        p.push_back({"cubic",
          { last.x(), last.y(), 0 },
          { s.point().x(), s.point().y(), 0 },
          { s.c1().x(), s.c1().y(), 0 },
          { s.c2().x(), s.c2().y(), 0 }});
        break;
      }
      last = s.point();
    }

    return p;
  };

  std::vector<contourklip::Contour> sources;
  for (const auto& c : args[0]) {
    sources.push_back(to_contour(c));
  }

  std::vector<contourklip::Contour> masks;
  for (const auto& c : args[1]) {
    masks.push_back(to_contour(c));
  }

  std::vector<contourklip::Contour> results{};

  auto mode_str = args[2];
  auto mode = mode_str == "intersection" ? contourklip::INTERSECTION :
              mode_str == "union"        ? contourklip::UNION :
              mode_str == "difference"   ? contourklip::DIFFERENCE :
              mode_str == "xor"          ? contourklip::XOR :
              mode_str == "divide"       ? contourklip::DIVIDE : contourklip::INTERSECTION;

  std::vector<uint8_t> buffer;
  if (contourklip::clip(sources, masks, results, mode)) {
    auto list = json::array();

    for (const auto& c : results) {
      list.push_back(to_path(c));
    }

    buffer = json::to_cbor(list);
  } else {
    buffer = json::to_cbor(json::array());
  }

  wasm_minimal_protocol_send_result_to_host(buffer.data(), buffer.size());
  return 0;
}
