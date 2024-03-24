
/* 
Contourklip, a contour clipping library which supports cubic beziers.

Copyright (C) 2022 verven [ vervencode@protonmail.com ]

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef CONTOURKLIP_CONTOURKLIP_HPP
#define CONTOURKLIP_CONTOURKLIP_HPP
#include <algorithm>
#include <array>
#include <cassert>
#include <cmath>
#include <deque>
#include <iostream>
#include <map>
#include <optional>
#include <set>
#include <vector>

#ifndef CONTOURKLIP_DIRECT_SOLVERS_HPP
#define CONTOURKLIP_DIRECT_SOLVERS_HPP
namespace directsolvers {
    double clip(double val, double lower, double upper) {
        return std::max(lower, std::min(val, upper));
    }

    /*
      see: https://stackoverflow.com/questions/63665010

      diff_of_products() computes a*b-c*d with a maximum error <= 1.5 ulp

      Claude-Pierre Jeannerod, Nicolas Louvet, and Jean-Michel Muller,
      "Further Analysis of Kahan's Algorithm for the Accurate Computation
      of 2x2 Determinants". Mathematics of Computation, Vol. 82, No. 284,
      Oct. 2013, pp. 2245-2264
    */
    double diff_of_products (double a, double b, double c, double d) {
        double w = d * c;
        double e = std::fma (-d, c, w);
        double f = std::fma (a, b, -w);
        return f + e;
    }


    int solve_quadratic(double a_0, double a_1, double a_2, std::pair<double, double> &r) {
        if (std::abs(a_2) < 1e-15) {
            if (std::abs(a_1) < 1e-15) {
                return 0;
            }
            r.first = r.second = -a_0 / a_1;
            return 1;
        }
        double d = diff_of_products(a_1, a_1, 4.0*a_2, a_0);
        if (d < 0) {
            return 0;
        }
        double sqd = sqrt(d);
        double u = 1.0 / a_2;
        if (a_1 >= 0.0) {
            double t = 0.5 * (-a_1 - sqd) * u;
            r.first = t;
            r.second = u * a_0 / t;
        } else {
            double t = 0.5 * (-a_1 + sqd) * u;
            r.first = u * a_0 / t;
            r.second = t;
        }
        return 2;
    }

    template<typename RootConsumer>
    void solve_cubic_real(double a_0, double a_1, double a_2, double a_3, RootConsumer &c, double tol) {
        //special case: not a cubic, fall back to quadratic
        if (std::abs(a_3) < tol) {
            std::pair<double, double> r{};
            int t = solve_quadratic(a_0, a_1, a_2, r);
            if (t == 1) {
                c(r.first);
            }
            if (t == 2) {
                c(r.first);
                c(r.second);
            }
            return;
        }
        //normalize so that highest coefficient is 1
        a_2 /= a_3;
        a_1 /= a_3;
        a_0 /= a_3;

        double a2_2 = a_2 * a_2;
        double a_2over3 = a_2 / 3.;
        double q = a_1 / 3.0 - a2_2 / 9.0;
        double r = (a_1 * a_2 - 3. * a_0) / 6.0 - (a2_2 * a_2) / 27.0;
        double rr = r * r;
        double q3 = q * q * q;
        double check = rr + q3;
        // case: three real solutions
        if (check <= 0 || check < tol) {
            double theta = 0;
            if (!(abs(q) < tol)) {
                double temp = clip(r / sqrt(-q3), -1, 1);
                theta = acos(temp);
            }
            double angle1 = theta / 3.;
            double angle2 = angle1 - 2. * M_PI / 3.;
            double angle3 = angle1 + 2. * M_PI / 3.;
            double sq = 2. * std::sqrt(-q);
            double r1, r2, r3;
            r1 = sq * cos(angle3) - a_2over3;
            r2 = sq * cos(angle2) - a_2over3;
            r3 = sq * cos(angle1) - a_2over3;
            // it holds that r1 <= r2 <= r3
            c(r1);
            c(r2);
            c(r3);
            return;

        }
        //only one real solution
        double sq = sqrt(check);
        double u = cbrt(r + sq);
        double v = cbrt(r - sq);
        double r1 = u + v - a_2over3;
        c(r1);
    }
}
#endif //CONTOURKLIP_DIRECT_SOLVERS_HPP
#ifndef CONTOURKLIP_POLYNOMIAL_SOLVER_HPP
#define CONTOURKLIP_POLYNOMIAL_SOLVER_HPP
namespace polynomialsolver {

    template<typename U, typename T>
    std::optional<T> itp_root_refine(U &func, T a, T b, T eps, int maxiter) {
        //leveraging argument dependent lookup
        using std::log2;
        using std::abs;
        using std::exp2;
        T a_start = a;
        T b_start = b;
        T k1 = (T) 0.2 / (b - a);
        int nmax =  int(log2((b - a) / (2 * eps))) + 2;
        int i = 0;
        T fa = func(a);
        T fb = func(b);
        while (b - a > 2 * eps && i < maxiter) {
            if(fa ==(T)0){
                return a;
            }
            if(fb==(T)0){
                return b;
            }
            //safety check in case interval is degenerate
            if(a < a_start || b > b_start) return {};
            if(fa * fb >0) return {};
            T x_mid = (a + b) / 2.0;
            T r = eps * (exp2(nmax - i)) - (b - a) / 2.0;
            T delta = k1 * (b - a) * (b - a);
            T x_f = (fb * a - fa * b) / (fb - fa);
            T si = x_mid - x_f;
            si = si < 0 ? -1 : 1;
            T x_t = (delta <= abs(x_mid - x_f)) ? x_f + si * delta : x_mid;
            T x_itp = (abs(x_t - x_mid) <= r) ? x_t : x_mid - si * r;
            T f_x = func(x_itp);
            if (f_x * fa < 0) {
                b = x_itp;
                fb = f_x;
            } else {
                a = x_itp;
                fa = f_x;
            }
            i++;
        }
        return (T)0.5*(a+b);
    }

    template<typename T>
    constexpr T linearinter(T p0, T p1, T t) {
        return (1 - t) * p0 + t * p1;
    }

    // casteljau subdivision using O(N) memory
    template<std::size_t N, typename T>
    void casteljau_subdiv(const std::array<T, N> &coeffs, T t, std::array<T, N> &res_first, std::array<T, N> &res_second) {
        std::array<std::array<T, N>, 2> table{};
        std::size_t curr = 0, prev = 0;
        for (std::size_t i = 0; i < N; ++i) {
            table[curr][i] = coeffs[i];
        }
        curr = 1;
        for (std::size_t i = 1; i < N; ++i) {
            for (std::size_t j = 0; j < N - i; ++j) {
                table[curr][j] = linearinter(table[prev][j], table[prev][j + 1], t);
            }
            res_first[i] = table[curr][0];
            res_second[N - i - 1] = table[curr][N - i - 1];
            prev = curr;
            curr = (1 - curr);
        }
        res_first[0] = coeffs[0];
        res_second[N - 1] = coeffs[N - 1];
    }

    // converts a polynomial from the monomial basis given by coeffs to the bezier basis by
    // storing the result in out. O(N^2) operation with O(N) memory
    template<std::size_t N, typename T>
    constexpr void basis_conversion(const std::array<T, N> &coeffs, std::array<T, N> &out) {
        long bin_c = 1;
        std::array<std::array<T, N>, 2> table{};
        for (std::size_t i = 0; i < N; ++i) {
            table[0][i] = coeffs[i] / ((T) bin_c);
            //careful about operation order
            bin_c = (bin_c * ((N - 1) - i)) / (i + 1);
        }

        std::size_t curr = 0, prev = 1;
        for (std::size_t i = 0; i < N; ++i) {
            out[i] = table[curr][0];
            prev = curr;
            curr = 1-curr;
            for (std::size_t j = 0; j < N - i -1; ++j) {
                table[curr][j] = table[prev][j] + table[prev][j +1];
            }
        }
    }

    // returns the number of sign changes in the coefficients. Numerically zero
    // coefficients  as given by the functor are ignored.
    template<std::size_t N, typename T, typename zeroF>
    constexpr int sign_changes(const std::array<T, N> &coeffs, zeroF& is_zero) {
        std::size_t start = 0, end = N - 1;
        while (start < N - 1 && is_zero(coeffs[start])) {
            start++;
        }
        // start ==  N -1 || c >0;
        while (end > 1 && is_zero(coeffs[end])) {
            end--;
        }
        T prev = coeffs[start];
        int out = 0;
        for (std::size_t i = start; i <= end; ++i) {
            if (is_zero(coeffs[i]) ) {
                continue;
            }
            if (coeffs[i] * prev < 0) {
                out++;
            }
            prev = coeffs[i];
        }
        return out;
    }

    // brackets the roots of the polynomial defined by the coeffs array, passes the interval to the callback
    template<std::size_t N, typename T, typename OutF>
    void rootbracket_bezier(const std::array<T, N> &coeffs, T a, T b, OutF &process, T abstol) {
        using std::abs;

        if (abs(b-a) <= abstol){
            return;
        }
        auto iszero = [&abstol](T d){
            return abs(d) <= abstol;
        };
        bool boundary1 = iszero(coeffs.front());
        bool boundary2 = iszero(coeffs.back());

        switch (sign_changes(coeffs, iszero)) {
            case 0:
                if(boundary1 && boundary2) break;
                if( boundary2 || (a ==0 && boundary1) ){
                    process({a, b});
                }
                return;
            case 1:
                if (!boundary1 && !boundary2) {
                    process({a, b});
                    return;
                }
        }
        T mid = 0.5 * (a + b);
        std::array<T, N> leftcoeffs{};
        std::array<T, N> rightcoeffs{};
        casteljau_subdiv(coeffs, (T) 0.5, leftcoeffs, rightcoeffs);
        rootbracket_bezier(leftcoeffs, a, mid, process, abstol);
        rootbracket_bezier(rightcoeffs, mid, b, process, abstol);
    }

    // Horner polynomial evaluation scheme.
    template<std::size_t N, typename T>
    constexpr T polyval(const std::array<T, N> &coeffs, T t) {
        T out = coeffs[N - 1];
        for (int i = N - 2; i >= 0; i--) {
            out = coeffs[i] + t * out;
        }
        return out;
    }

    // derivative of polynomial
    template<std::size_t N, typename T>
    constexpr void poly_der(const std::array<T, N> &coeffs, std::array<T, N - 1> &out) {
        for (int i = 1; i < N; ++i) {
            out[i - 1] = coeffs[i] * i;
        }
    }

    template<std::size_t N, typename T, bool BezierRepr = false>
    struct PolynomialFunc {
        std::array<T, N> coeffs;
        explicit PolynomialFunc(const std::array<T, N> &poly) : coeffs(poly) {}

        PolynomialFunc<N - 1, T, BezierRepr> derivative(){
            std::array<T, N> derivative_coeffs;
            if constexpr(BezierRepr){
                poly_der_bezier(coeffs, derivative_coeffs);
            } else{
                poly_der(coeffs, derivative_coeffs);
            }
            return {derivative_coeffs};
        }
        T operator()(T x) const{
            if constexpr(BezierRepr){
                return polyeval_bezier(coeffs, x);
            }else{
                return polyval(coeffs, x);
            }
        }
    };

    template<std::size_t N, typename T, typename IntervalConsumer>
    void rootbracket(const std::array<T, N> &poly, IntervalConsumer &out, T abstol = 1e-15) {
        using std::abs;
        T acc = 0;
        for (const auto &c: poly) {
            acc += abs(c);
        }
        if(abs(acc)  <= abstol){
            return;
        }
        std::array<T, N> bezier_coeffs{};
        basis_conversion(poly, bezier_coeffs);
        rootbracket_bezier(bezier_coeffs, (T) 0, (T) 1, out, abstol);
    }

    // numerically computes roots of the input coeffs, given in monomial basis form.
    template<std::size_t N, typename T, typename RootConsumer>
    void getpolyroots(const std::array<T, N> &poly, RootConsumer &out,
                      int niter = 25, T abstol = 1e-15, T interval_eps = 1e-20) {
        //Note that intervals are added in increasing order
        std::size_t numroots =0;
        std::array<std::pair<T, T>, N> root_intervals{};
        auto add = [&](const std::pair<T, T>& interval){
            if(numroots < N) root_intervals[numroots++] = interval;
        };
        using std::abs;
        rootbracket(poly,  add, abstol);
        PolynomialFunc poly_function{poly};
        for (std::size_t i = 0; i < numroots; ++i) {
            auto [a, b] = root_intervals[i];
            // by assumption each interval contains exactly 1 root
            if(abs(poly_function(a))<abstol) {
                out(a);
                continue;
            }
            if(abs(poly_function(b))<abstol) {
                out(b);
                continue;
            };
            if (auto curr = itp_root_refine(poly_function, a, b, (T) interval_eps, niter)){
                out(*curr);
            }
        }
    }

    // convenience function that returns the monomial representation of the polynomial
    // defined by the N input roots. The leading coefficient is not normalized.
    template<std::size_t N, typename T>
    std::array<T, N + 1> poly_from_roots(const std::array<T, N> roots) {
        std::array<T, N + 1> out{};
        out[0] = -roots[0];
        out[1] = 1;
        for (std::size_t i = 1; i < roots.size(); ++i) {
            for (int j = i; j >= 0; --j) {
                out[j + 1] = out[j];
            }
            out[0] = 0;
            for (int j = 0; j < i + 1; ++j) {
                out[j] += out[j + 1] * -roots[i];
            }
        }
        return out;
    }
}
#endif //CONTOURKLIP_POLYNOMIAL_SOLVER_HPP
#ifndef CONTOURKLIP_GEOMETRY_BASE_HPP
#define CONTOURKLIP_GEOMETRY_BASE_HPP


namespace contourklip {
    struct Point2d {
    private:
        double _x;
        double _y;
    public:
        constexpr Point2d(double x, double y) : _x(x), _y(y) {}

        constexpr Point2d() : _x(0), _y(0) {}

        inline constexpr double x() const {
            return _x;
        }

        inline constexpr double y() const {
            return _y;
        }

        inline constexpr double& x() {
            return _x;
        }

        inline constexpr double& y() {
            return _y;
        }

        template<int idx>
        friend constexpr double get(const Point2d &p) {
            static_assert(idx == 0 || idx == 1);
            if constexpr(idx == 0) {
                return p.x();
            } else {
                return p.y();
            }
        }
    };

    template<int idx>
    constexpr double get(const Point2d &p);

    std::ostream &operator<<(std::ostream &o, const Point2d &p) {
        return o << "(" << p.x() << ", " << p.y() << ")";
    }

    inline bool operator==(const Point2d &p1, const Point2d &p2) {
        return (p1.x() == p2.x()) && (p1.y() == p2.y());
    }

    inline bool operator!=(const Point2d &p1, const Point2d &p2) { return !(p1 == p2); }

    constexpr auto increasing = [](const Point2d &a, const Point2d &b) {
        if (a.x() == b.x()) {
            return a.y() < b.y();
        }
        return a.x() < b.x();
    };

    bool operator<(const Point2d &a, const Point2d &b) { return increasing(a, b); }

    namespace detail {

        inline bool approx_equal(const Point2d &p1, const Point2d &p2, double eps) {
            return std::abs(p1.x() - p2.x()) < eps && std::abs(p1.y() - p2.y()) < eps;
        }

        inline double signed_area(const Point2d &p0, const Point2d &p1, const Point2d &p2) {
            using namespace directsolvers;
            return diff_of_products(p0.x() - p2.x(), p1.y() - p2.y(), p1.x() - p2.x(), p0.y() - p2.y());
        }
//
//        auto left_of_line = [](const Point2d &p0, const Point2d &p1, const Point2d &a) -> bool {
//            return signed_area(p0, p1, a) > 0;
//        };
//
//        auto is_collinear = [](const Point2d &a, const Point2d &b, const Point2d &p) -> bool {
//            if (a.x() == b.x()) {
//                return a.x() == p.x();
//            }
//            if (a.y() == b.y()) {
//                return a.y() == p.y();
//            }
//            return signed_area(a, b, p) == 0;
//        };

        struct LeftOfLine{
            bool operator()(const Point2d &p0, const Point2d &p1, const Point2d &a) const{
                return signed_area(p0, p1, a) > 0;
            }
        };

        struct IsCollinear{
            bool operator()(const Point2d &a, const Point2d &b, const Point2d &p) const{
                if (a.x() == b.x()) {
                    return a.x() == p.x();
                }
                if (a.y() == b.y()) {
                    return a.y() == p.y();
                }
                return signed_area(a, b, p) == 0;
            }
        };

        template<typename Orient2dFunc = LeftOfLine>
        inline bool above_line(const Point2d &a, const Point2d &b, const Point2d &p, const Orient2dFunc &on_left = {}) {
            return increasing(a, b) ? on_left(a, b, p) : on_left(b, a, p);
        }

        double triangle_area(double x1, double y1, double x2, double y2, double x3, double y3) {
            return 0.5 * (x1 * (y2 - y3) +
                          x2 * (y3 - y1) +
                          x3 * (y1 - y2));
        }

        double quadri_area(const Point2d &a, const Point2d &b, const Point2d &c, const Point2d &d) {
            return triangle_area(a.x(), a.y(), b.x(), b.y(), c.x(), c.y())
                   + triangle_area(c.x(), c.y(), d.x(), d.y(), a.x(), a.y());
        }

        inline double sqdist(const Point2d &a, const Point2d &b) {
            double x = a.x() - b.x();
            double y = a.y() - b.y();
            return x * x + y * y;
        }

        inline double dist(const Point2d &a, const Point2d &b) {
            return sqrt(sqdist(a, b));
        }

        double sqdist_to(const Point2d &a, const Point2d &b, const Point2d &p) {
            double dx = b.x() - a.x();
            double dy = b.y() - a.y();
            double num = dy * p.x() - dx * p.y() + b.x() * a.y() - b.y() * a.x();
            double den = dy * dy + dx * dx;
            return num * num / den;
        }

        inline bool in_range(double x, double a, double b) {
            return a < x && x < b;
        }

        inline bool in_range_strict(double a, double b, double x) {
            return a < x && x < b;
        }

        inline bool in_range_closed(double a, double b, double x) {
            return a <= x && x <= b;
        }

        inline bool in_interval(double a, double b, double x) {
            return a < b ? in_range(x, a, b) : in_range(x, b, a);
        }

        inline bool in_box(const Point2d &a, const Point2d &b, const Point2d &p) {
            return in_interval(a.x(), b.x(), p.x()) && in_interval(a.y(), b.y(), p.y());
        }

        Point2d basic_intersection(const Point2d &p1, const Point2d &p2, const Point2d &p3, const Point2d &p4) {
            double den = ((p1.x() - p2.x()) * (p3.y() - p4.y()) - (p1.y() - p2.y()) * (p3.x() - p4.x()));
            double px = ((p1.x() * p2.y() - p1.y() * p2.x()) * (p3.x() - p4.x())
                         - (p1.x() - p2.x()) * (p3.x() * p4.y() - p3.y() * p4.x()))
                        / den;
            double py = ((p1.x() * p2.y() - p1.y() * p2.x()) * (p3.y() - p4.y()) -
                         (p1.y() - p2.y()) * (p3.x() * p4.y() - p3.y() * p4.x()))
                        / den;
            return {px, py};
        }

        class BBox {
        public:
            double min_x;
            double min_y;
            double max_x;
            double max_y;

            inline bool weak_contains(const Point2d &p) const {
                return min_x <= p.x() && p.x() <= max_x
                       && min_y <= p.y() && p.y() <= max_y;
            }

            inline bool strict_contains(const Point2d &p) const {
                return min_x < p.x() && p.x() < max_x
                       && min_y < p.y() && p.y() < max_y;
            }

            inline bool strict_contains_x(const double &x) const {
                return min_x < x && x < max_x;
            }

            inline bool strict_contains_y(const double &y) const {
                return min_y < y && y < max_y;
            }

            inline bool weak_contains_x(const double &x) const {
                return min_x <= x && x <= max_x;
            }

            inline bool weak_contains_y(const double &y) const {
                return min_y <= y && y <= max_y;
            }

            inline bool weak_overlap(const BBox &other) const {
                bool vertical = weak_contains_x(other.min_x)
                                || weak_contains_x(other.max_x)
                                || other.weak_contains_x(this->min_x)
                                || other.weak_contains_x(this->max_x);
                bool horizontal = weak_contains_y(other.min_y)
                                  || weak_contains_y(other.max_y)
                                  || other.weak_contains_y(this->min_y)
                                  || other.weak_contains_y(this->max_y);
                return vertical && horizontal;
            }

            inline bool strict_overlap(const BBox &other) const {
                if (weak_overlap(other)) {
                    bool vertical = strict_contains_x(other.min_x)
                                    || strict_contains_x(other.max_x)
                                    || other.strict_contains_x(this->min_x)
                                    || other.strict_contains_x(this->max_x);
                    bool horizontal = strict_contains_y(other.min_y)
                                      || strict_contains_y(other.max_y)
                                      || other.strict_contains_y(this->min_y)
                                      || other.strict_contains_y(this->max_y);
                    return vertical || horizontal;
                }
                return false;
            }


            friend std::ostream &operator<<(std::ostream &o, const BBox &bbox) {
                return o << "[" << Point2d{bbox.min_x, bbox.min_y}
                         << ", " << Point2d{bbox.max_x, bbox.max_y} << "]";
            }
        };

        struct Segment {
            Point2d first;
            Point2d second;

            friend std::ostream &operator<<(std::ostream &o, const Segment &p) {
                return o << "[" << p.first << ", " << p.second << "]";
            }
        };

        inline Point2d linear_map(const Point2d &first, const Point2d &second, double t) {
            return {first.x() + t * (second.x() - first.x()), first.y() + t * (second.y() - first.y())};
        }

        inline Point2d linear_map(const Segment &seg, double t) {
            return linear_map(seg.first, seg.second, t);
        }

        inline bool vertical(const Point2d &a, const Point2d &b) {
            return a.x() == b.x();
        }

        inline bool horizontal(const Point2d &a, const Point2d &b) {
            return a.y() == b.y();
        }

        template<typename T>
        T segment_tval(const T &a_x, const T &a_y, const T &b_x, const T &b_y, const T &p_x, const T &p_y) {
            return a_x;
        }

        double segment_tval(const Segment &seg, const Point2d &p) {
            if (p == seg.first) return 0;
            if (p == seg.second) return 1;
            if (seg.second.x() == seg.first.x()) {
                return (p.y() - seg.first.y()) / (seg.second.y() - seg.first.y());
            }
            return (p.x() - seg.first.x()) / (seg.second.x() - seg.first.x());
        }

        BBox make_bbox(const Segment &seg) {
            double min_x = std::min(seg.first.x(), seg.second.x());
            double min_y = std::min(seg.first.y(), seg.second.y());
            double max_x = std::max(seg.first.x(), seg.second.x());
            double max_y = std::max(seg.first.y(), seg.second.y());
            return {min_x, min_y, max_x, max_y};
        }

        struct SegInter {
            double t1;
            double t2;
            Point2d p;
        };

        std::ostream &operator<<(std::ostream &o, const SegInter &q) {
            return o << "[" << q.p << " " << q.t1 << " " << q.t2 << "]";
        }

        bool operator==(const SegInter &a, const SegInter &b) {
            return a.t1 == b.t1 && a.t2 == b.t2 && a.p == b.p;
        }

        // returns a SegInter if the following 3 conditions hold:
        // a) the segments do not share any endpoint
        // b) the segments are not parallel
        // c) at least one of the segments is split in 2 new segments by the other segment
        // note that points are passed by value
        template<typename collinearF = IsCollinear>
        std::optional<SegInter> intersect_segments_detail(Point2d a1,
                                                          Point2d a2,
                                                          Point2d b1,
                                                          Point2d b2) {
            if (a1 == b1
                || a2 == b2
                || a1 == b2
                || a2 == b1
                    ) {
                return {};
            }
            collinearF collinear;
            bool b1_on_a = collinear(a1, a2, b1);
            bool b2_on_a = collinear(a1, a2, b2);
            if (b1_on_a && b2_on_a) {
                return {};
            }

            auto make_inter = [&](double t, double u, const Point2d &p) -> SegInter {
                double a = t, b = u;
                return SegInter{a, b, p};
            };

            double x1 = a1.x(), y1 = a1.y();
            double x2 = a2.x(), y2 = a2.y();
            double x3 = b1.x(), y3 = b1.y();
            double x4 = b2.x(), y4 = b2.y();

            using namespace directsolvers;
            double den = diff_of_products((x1 - x2), (y3 - y4), (y1 - y2), (x3 - x4));
            double num1 = diff_of_products((x1 - x3), (y3 - y4), (y1 - y3), (x3 - x4));
            double num2 = diff_of_products((x2 - x1), (y1 - y3), (y2 - y1), (x1 - x3));

            bool a_notinrange = num1 * den < 0 || std::abs(num1) > std::abs(den);
            bool b_notinrange = num2 * den < 0 || std::abs(num2) > std::abs(den);
            if (b1_on_a) {
                if (a_notinrange) {
                    return {};
                }
                return make_inter(num1 / den, 0, b1);
            }
            if (b2_on_a) {
                if (a_notinrange) {
                    return {};
                }
                return make_inter(num1 / den, 1, b2);
            }
            bool a1_on_b = collinear(b1, b2, a1);
            bool a2_on_b = collinear(b1, b2, a2);
            if (a1_on_b) {
                if (b_notinrange) {
                    return {};
                }
                return make_inter(0, num2 / den, a1);
            }
            if (a2_on_b) {
                if (b_notinrange) {
                    return {};
                }
                return make_inter(1, num2 / den, a2);
            }
            if (a_notinrange || b_notinrange) {
                return {};
            }
            return make_inter(num1 / den, num2 / den, linear_map(a1, a2, num1 / den));
        }

        template<typename collinearF = IsCollinear>
        std::optional<SegInter> intersect_segments(Point2d a1, Point2d a2, Point2d b1, Point2d b2) {
            if (a1 == b1
                || a2 == b2
                || a1 == b2
                || a2 == b1
                    ) {
                return {};
            }
            collinearF collinear;
            bool b1_on_a = collinear(a1, a2, b1);
            bool b2_on_a = collinear(a1, a2, b2);
            if (b1_on_a && b2_on_a) {
                return {};
            }
            bool a_reversed = false, b_reversed = false;
            bool segments_swapped = false;

            if ((a_reversed = !increasing(a1, a2))) {
                std::swap(a1, a2);
            }
            if ((b_reversed = !increasing(b1, b2))) {
                std::swap(b1, b2);
            }
            double dx1 = a2.x() - a1.x(), dy1 = a2.y() - a1.y();
            double dx2 = b2.x() - b1.x(), dy2 = b2.y() - b1.y();

            if (!increasing({dx1, dy1}, {dx2, dy2})) {
                std::swap(a1, b1);
                std::swap(a2, b2);
                segments_swapped = true;
            }
            if (auto ret = intersect_segments_detail(a1, a2, b1, b2)) {
                if (segments_swapped) {
                    std::swap(ret->t1, ret->t2);
                }
                if (a_reversed) {
                    ret->t1 = 1 - ret->t1;
                }
                if (b_reversed) {
                    ret->t2 = 1 - ret->t2;
                }
                return ret;
            }
            return {};
        }

        template<typename collinearF = IsCollinear>
        std::optional<SegInter> intersect_segments(const Segment &a, const Segment &b) {
            return intersect_segments(a.first, a.second, b.first, b.second);
        }

        struct CubicBezier {
            Point2d p0;
            Point2d p1;
            Point2d p2;
            Point2d p3;

            CubicBezier() = default;

            CubicBezier(const Point2d &p0, const Point2d &p1, const Point2d &p2, const Point2d &p3) : p0(p0), p1(p1),
                                                                                                      p2(p2), p3(p3) {}

            explicit CubicBezier(std::array<Point2d, 4> &in) {
                p0 = in[0];
                p1 = in[1];
                p2 = in[2];
                p3 = in[3];
            }

            constexpr std::array<Point2d, 4> as_array() const {
                return {p0, p1, p2, p3};
            }

            friend std::ostream &operator<<(std::ostream &o, const CubicBezier &p) {
                return o << "[" << p.p0 << " " << p.p1 << " " << p.p2 << " " << p.p3 << "]";
            }

            friend bool operator==(const CubicBezier &a, const CubicBezier &b) {
                return a.as_array() == b.as_array();
            }
        };

        inline void make_hull_bbox(const CubicBezier &c, BBox &out) {
            double min_x = std::min(c.p0.x(), c.p3.x());
            double min_y = std::min(c.p0.y(), c.p3.y());
            double max_x = std::max(c.p0.x(), c.p3.x());
            double max_y = std::max(c.p0.y(), c.p3.y());
            out.min_x = std::min(min_x, std::min(c.p1.x(), c.p2.x()));
            out.min_y = std::min(min_y, std::min(c.p1.y(), c.p2.y()));
            out.max_x = std::max(max_x, std::max(c.p1.x(), c.p2.x()));
            out.max_y = std::max(max_y, std::max(c.p1.y(), c.p2.y()));
        }
    }
    class Contour;

    enum ComponentType {
        LINE = 0,
        CUBIC_BEZIER = 1,
    };

    /// \brief a simple struct to represent a segment of a path.
    struct ContourComponent {
        friend class Contour;
    private:
        ComponentType component_type_;
        Point2d c_1_;
        Point2d c_2_;
        Point2d point_;
    public:
        /// \brief constructs an instance this representing a line segment of a Contour.
        /// If given a Contour c, adding this to it will represent the segment [c.back_point(), this->point()]
        /// \param pLast the point_ Point2d representing the end point
        explicit ContourComponent(const Point2d &p) : component_type_(LINE), point_(p) {}

        /// \brief constructs an instance representing a cubic bezier segment of a contour.
        /// given some first point p, it will represent the bezier [p, c1, c2, point].
        /// \param p_1 the first Point2d control point
        /// \param p_2 the second Point2d control point
        /// \param p_last the Point2d endpoint
        ContourComponent(const Point2d &c_1,
                         const Point2d &c_2,
                         const Point2d &p) :
                component_type_(CUBIC_BEZIER), c_1_(c_1), c_2_(c_2), point_(p) {}

        Point2d c1() const {
            return c_1_;
        }

        Point2d& c1() {
            return c_1_;
        }

        Point2d c2() const {
            return c_2_;
        }

        Point2d& c2() {
            return c_2_;
        }

        Point2d point() const {
            return point_;
        }

        Point2d &point() {
            return point_;
        }

        bool bcurve() const {
            return segment_shape() == CUBIC_BEZIER;
        }

        /// \brief returns the shape type tag associated with this instance.
        /// \return the shape type ComponentType
        ComponentType segment_shape() const {
            return component_type_;
        }

        friend bool operator==(const ContourComponent &a, const ContourComponent &b) {
            if (a.component_type_ != b.component_type_) {
                return false;
            }
            if (a.bcurve()) {
                return a.c1() == b.c1()
                       && a.c2() == b.c2()
                       && a.point() == b.point();
            }
            return a.point() == b.point();
        }

    private:
        /// \brief reverses the control points associated with this, irrespective of the shape type.
        void reverse_controlp() {
            Point2d temp = c_1_;
            c_1_ = c_2_;
            c_2_ = temp;
        }

    };

    std::ostream &operator<<(std::ostream &o, const ContourComponent &comp) {
        switch (comp.segment_shape()) {
            case CUBIC_BEZIER:
                return o << comp.c1() << " " << comp.c2() << " " << comp.point();
            case LINE:
                return o << comp.point();
        }
        return o;
    }

    class Contour {
    private:
        using ContainerType = std::vector<ContourComponent>;
        ContainerType container{};
    public:
        Contour() = default;

        explicit Contour(const Point2d &start) {
            push_back(start);
        }

        Contour(const Point2d &p0, const Point2d &p1, const Point2d &p2, const Point2d &p3) {
            push_back(p0);
            push_back(p1, p2, p3);
        }

        Contour(const Point2d &p0, const Point2d &p1) {
            push_back(p0);
            push_back(p1);
        }

        void push_back(const Point2d &p) {
            push_back(ContourComponent(p));
        }

        void push_back(const Point2d &p2,
                       const Point2d &p3,
                       const Point2d &p) {
            push_back(
                    ContourComponent{p2, p3, p}
            );
        }

        void push_back(const ContourComponent &start) {
            container.push_back(start);
        }

        ContourComponent operator[](const std::size_t idx) const {
            return container[idx];
        }

        ContourComponent& operator[](const std::size_t idx) {
            return container[idx];
        }

        std::size_t size() const {
            return container.size();
        }

        Point2d front_point() const {
            return container.front().point();
        }

        Point2d back_point() const {
            return container.back().point();
        }


        ContourComponent &front() {
            return container.front();
        }

        ContourComponent &back() {
            return container.back();
        }

        ContourComponent front() const {
            return container.front();
        }

        ContourComponent back() const {
            return container.back();
        }

        bool is_closed() const {
            return front_point() == back_point();
        }

        void close() {
            if (!is_closed()) {
                this->push_back(front_point());
            }
        }

        void reverse() {
            std::reverse(container.begin(), container.end());
            for (std::size_t i = 0; i < container.size() - 1; ++i) {
                container[i].point() = container[i + 1].point();
                if (container[i].segment_shape() == CUBIC_BEZIER) {
                    container[i].reverse_controlp();
                }
            }
            //rotate to the right so that we start with a simple point.
            std::rotate(container.rbegin(), container.rbegin() + 1, container.rend());
        }

        template<ComponentType T, typename Consumer>
        void forward_segments(Consumer &out) const {
            if (container.empty()) { return; }
            auto it = container.begin();
            for (auto prev = it++; it != container.end(); prev++, it++) {
                auto pair = std::make_pair(*prev, *it);
                if (pair.second.segment_shape() == T) {
                    if constexpr (T == LINE) {
                        out(pair.first.point(), pair.second.point());
                    } else {
                        out(pair.first.point(),
                            pair.second.c1(),
                            pair.second.c2(),
                            pair.second.point());
                    }
                }
            }
        }

        auto begin() const {
            return container.begin();
        }

        auto begin() {
            return container.begin();
        }

        auto end() const {
            return container.end();
        }

        auto end() {
            return container.end();
        }

        friend bool operator==(const Contour &a, const Contour &b) {
            return a.container == b.container;
        }

        friend std::ostream &operator<<(std::ostream &o, const Contour &c) {
            for (const auto &seg: c) {
                std::cout << seg << '\n';
            }
            return o;
        }
    };


    namespace detail {
        std::tuple<double, double, double, double> contourbbox(const Contour &a) {
            double min_x = a.front_point().x();
            double max_x = min_x;
            double min_y = a.front_point().y();
            double max_y = min_y;
            for (const auto &seg: a) {
                min_x = std::min(min_x, seg.point().x());
                min_y = std::min(min_y, seg.point().y());
                max_x = std::max(max_x, seg.point().x());
                max_y = std::max(max_y, seg.point().y());
                switch (seg.segment_shape()) {
                    case LINE:
                        continue;
                    case CUBIC_BEZIER:
                        min_x = std::min(min_x, std::min(seg.c1().x(), seg.c2().x()));
                        min_y = std::min(min_y, std::min(seg.c1().y(), seg.c2().y()));
                        max_x = std::max(max_x, std::max(seg.c1().x(), seg.c2().x()));
                        max_y = std::max(max_y, std::max(seg.c1().y(), seg.c2().y()));
                        continue;
                }
            }
            return {min_x, min_y, max_x, max_y};
        }

        double bezier_area(const Point2d &p0, const Point2d &p1,
                           const Point2d &p2, const Point2d p3) {
            double x0 = p0.x(), y0 = p0.y(), x1 = p1.x(), y1 = p1.y(),
                    x2 = p2.x(), y2 = p2.y(), x3 = p3.x(), y3 = p3.y();
            return (x0 * (-2 * y1 - y2 + 3 * y3)
                    + x1 * (2 * y0 - y2 - y3)
                    + x2 * (y0 + y1 - 2 * y3)
                    + x3 * (-3 * y0 + y1 + 2 * y2)
                   ) * 3. / 20.;
        }

        double contour_area(const Contour &c) {
            if (c.size() < 2) return 0.;
            double area = 0.0;
            for (std::size_t i = 0; i < c.size() - 1; ++i) {
                area += c[i].point().x() * c[i + 1].point().y()
                        - c[i + 1].point().x() * c[i].point().y();
                if (c[i + 1].segment_shape() == CUBIC_BEZIER) {
                    double t = bezier_area(c[i].point(), c[i + 1].c1(),
                                           c[i + 1].c2(), c[i + 1].point());
                    //mult. by 2 since at the end we div by 2.
                    area -= 2 * t;
                }
            }
            if (!c.is_closed()) {
                // we only have an implicit line segment
                area += c.back_point().x() * c.front_point().y()
                        - c.back_point().x() * c.front_point().y();
            }
            return 0.5 * area;
        }

        double multipolygon_area(const std::vector<Contour> &poly) {
            double area = 0;
            for (const auto &c: poly) {
                area += contour_area(c);
            }
            return area;
        }
    }
}
#endif //CONTOURKLIP_GEOMETRY_BASE_HPP
#ifndef CONTOURKLIP_BEZIER_UTILS_HPP
#define CONTOURKLIP_BEZIER_UTILS_HPP


namespace contourklip::detail {

        template<typename T>
        T beziermap(const T &p0, const T &p1, const T &p2, const T &p3, const T &t) {
            return (1 - t) * (1 - t) * (1 - t) * p0 + 3 * (1 - t) * (1 - t) * t * p1 + 3 * (1 - t) * t * t * p2 +
                   t * t * t * p3;
        }

        Point2d beziermap(const CubicBezier &c, const double t) {
            return {
                    beziermap(c.p0.x(), c.p1.x(), c.p2.x(), c.p3.x(), t),
                    beziermap(c.p0.y(), c.p1.y(), c.p2.y(), c.p3.y(), t)
            };
        }

        Point2d beziermap(const Point2d &p0, const Point2d &p1, const Point2d &p2, const Point2d &p3, const double t) {
            return {
                    beziermap(p0.x(), p1.x(), p2.x(), p3.x(), t),
                    beziermap(p0.y(), p1.y(), p2.y(), p3.y(), t)
            };
        }

        std::pair<CubicBezier, CubicBezier> casteljau_split(const CubicBezier &c, double t) {

            double x0 = c.p0.x(), y0 = c.p0.y();
            double x1 = c.p1.x(), y1 = c.p1.y();
            double x2 = c.p2.x(), y2 = c.p2.y();
            double x3 = c.p3.x(), y3 = c.p3.y();

            double x12 = (x1 - x0) * t + x0;
            double y12 = (y1 - y0) * t + y0;

            double x23 = (x2 - x1) * t + x1;
            double y23 = (y2 - y1) * t + y1;

            double x34 = (x3 - x2) * t + x2;
            double y34 = (y3 - y2) * t + y2;

            double x123 = (x23 - x12) * t + x12;
            double y123 = (y23 - y12) * t + y12;

            double x234 = (x34 - x23) * t + x23;
            double y234 = (y34 - y23) * t + y23;

            //instead of computing it from the above values, this way ensures consistency wrt. roundoff.
            Point2d split = beziermap(c, t);

            return {
                    CubicBezier{{x0, y0}, {x12, y12}, {x123, y123}, split},
                    CubicBezier{split, {x234, y234}, {x34, y34}, {x3, y3}}
            };
        }

        Point2d scaleto(const Point2d &a, const Point2d &b, double scale) {

            double d = dist(a, b);
            double vx = b.x() - a.x(), vy = b.y() - a.y();
            return {scale * 1. / d * vx + a.x(), scale * 1. / d * vy + a.y()};
        }

        CubicBezier bezier_merge(const CubicBezier &a, const CubicBezier &b) {

            double l_b = dist(b.p0, b.p1);
            double r_a = dist(a.p2, a.p3);
            double ratio = l_b / r_a;

            double q1_x = (ratio + 1) * a.p1.x() - ratio * a.p0.x();
            double q1_y = (ratio + 1) * a.p1.y() - ratio * a.p0.y();

            double q2_x = (1. / ratio) * ((ratio + 1) * b.p2.x() - b.p3.x());
            double q2_y = (1. / ratio) * ((ratio + 1) * b.p2.y() - b.p3.y());

            return {a.p0, {q1_x, q1_y}, {q2_x, q2_y}, b.p3};
        }

        std::optional<CubicBezier> sub_bezier(const CubicBezier &c, double t, double u) {

            auto[l1, r1] = casteljau_split(c, t);
            if (u == 1) {
                return r1;
            }
            auto[l2, r2] = casteljau_split(c, u);
            if (t == 0) {
                return l2;
            }

            // we have a quadratic bezier
            if (c.p3 == c.p2 || c.p0 == c.p1) {
                Point2d inter = basic_intersection(r1.p0, r1.p1, l2.p2, l2.p3);
                Point2d p1 = linear_map(r1.p0, inter, 2. / 3.);
                Point2d p2 = linear_map(inter, l2.p3, 1. / 3.);
                return {{r1.p0, p1, p2, l2.p3}};
            }

            double d = dist(r2.p0, r2.p1);
            double rx = r1.p2.x() - r2.p2.x();
            double ry = r1.p2.y() - r2.p2.y();
            double ratio;
            if (std::abs(rx) > std::abs(ry)) {
                ratio = (r2.p2.x() - r2.p3.x()) / (rx);
            } else {
                ratio = (r2.p2.y() - r2.p3.y()) / (ry);
            }

            if (std::isnan(ratio) || ratio == 0) {
                return {};
            }

            double right_dist = d / ratio;
            double p1_x = (r1.p1.x() + ratio * r1.p0.x()) / (ratio + 1.);
            double p1_y = (r1.p1.y() + ratio * r1.p0.y()) / (ratio + 1.);
            Point2d p1{p1_x, p1_y};
            Point2d p2 = scaleto(l2.p3, l2.p2, right_dist);

            return {CubicBezier{l1.p3, p1, p2, r2.p0}};
        }

        inline double control_poly_area(const CubicBezier &c) {
            return quadri_area(c.p0, c.p1, c.p2, c.p3);
        }

        void reverse(CubicBezier &c) {
            Point2d tmp = c.p0;
            c.p0 = c.p3;
            c.p3 = tmp;
            tmp = c.p1;
            c.p1 = c.p2;
            c.p2 = tmp;
        }

//        bool degenerate(const CubicBezier &c) {
//            return is_collinear(c.p0, c.p1, c.p2) && is_collinear(c.p1, c.p2, c.p3);
//        }

        std::pair<std::array<double, 4>, std::array<double, 4>> bezier_transpose(
                const CubicBezier &c) {
            return {{c.p0.x(), c.p1.x(), c.p2.x(), c.p3.x()},
                    {c.p0.y(), c.p1.y(), c.p2.y(), c.p3.y()}};
        }

        template<typename PointMap>
        CubicBezier transform(const CubicBezier &c, PointMap &f) {
            CubicBezier out{};
            out.p0 = f(c.p0);
            out.p1 = f(c.p1);
            out.p2 = f(c.p2);
            out.p3 = f(c.p3);
            return out;
        }

        inline bool unit_inter(double t) {
            return 0 <= t && t <= 1;
        }

        inline Point2d rotate_pt(const Point2d &in, const Point2d &rpoint, double cos_val, double sin_val) {
            double offx = in.x() - rpoint.x(), offy = in.y() - rpoint.y();
            return {offx * cos_val - offy * sin_val + rpoint.x(),
                    offx * sin_val + offy * cos_val + rpoint.y()};
        }

        inline Point2d
        rotate_translate_pt(const Point2d &in, const Point2d &rpoint, const Point2d &subtract, double cos_val,
                            double sin_val) {
            auto t = rotate_pt(in, rpoint, cos_val, sin_val);
            return {t.x() - subtract.x(), t.y() - subtract.y()};
        }

        std::pair<double, double>
        axis_align_rotate_vals(const Point2d p_start, const Point2d p_end, double abstol = 1e-8) {
            if (std::abs(p_start.y() - p_end.y()) < abstol) {
                return {1., 0.};
            } else {
                double vx = (p_end.x() - p_start.x()), vy = (p_end.y() - p_start.y());
                double cos_val, sin_val;
                if (std::abs(vx) < abstol) {
                    cos_val = 0;
                    sin_val = vy > 0 ? -1 : 1;
                } else {

                    double d = -vy / vx;
                    cos_val = 1. / std::sqrt(1 + d * d);
                    sin_val = d * cos_val;
                }
                return {cos_val, sin_val};
            }
        }

        template<typename T>
        std::tuple<T, T, T, T> cubic_line_coeffs(const T &a, const T &b, const T &c, const T &d) {
            T a_0 = a;
            T a_1 = -3 * a + 3 * b;
            T a_2 = 3 * a - 6 * b + 3 * c;
            T a_3 = -1 * a + 3 * b - 3 * c + d;
            return {a_0, a_1, a_2, a_3};
        }

        template<int D>
        std::tuple<double, double, double, double> cubic_line_coeffs(const CubicBezier &c) {
            static_assert(D == 0 || D == 1);
            double a_0 = get<D>(c.p0);
            double a_1 = -3 * get<D>(c.p0) + 3 * get<D>(c.p1);
            double a_2 = 3 * get<D>(c.p0) - 6 * get<D>(c.p1) + 3 * get<D>(c.p2);
            double a_3 = -1 * get<D>(c.p0) + 3 * get<D>(c.p1) - 3 * get<D>(c.p2) + get<D>(c.p3);
            return {a_0, a_1, a_2, a_3};
        }

        // returns the smallest parametric t value in the bezier interval such that B_x(t) = x.
        double t_from_x(const CubicBezier &c, double x, double cubic_tol = 1e-9) {
            auto[a_0, a_1, a_2, a_3] = cubic_line_coeffs<0>(c);
            a_0 -= x;
            double val = 1;
            auto rootprocess = [&val](double t) {
                if (in_range(t, 0, 1)) {
                    val = std::min(val, t);
                }
            };
            directsolvers::solve_cubic_real(a_0, a_1, a_2, a_3, rootprocess, cubic_tol);
            return val;
        }

        template<typename ConsumerF>
        void t_vals_from_x(const CubicBezier &c, double x, ConsumerF &f, double cubic_tol = 1e-9) {
            auto[a_0, a_1, a_2, a_3] = cubic_line_coeffs<0>(c);
            a_0 -= x;
            directsolvers::solve_cubic_real(a_0, a_1, a_2, a_3, f, cubic_tol);
        }

        bool curve_below(const CubicBezier &c, const Point2d &p) {
            double t = t_from_x(c, p.x());
            return beziermap(c, t).y() < p.y();
        }

        bool bezier_direction(const CubicBezier &c) {
            double area = quadri_area(c.p0, c.p1, c.p2, c.p3);
            if (area == 0) {
                return increasing(c.p0, c.p3);
            }
            return area > 0;
        }

        enum Extremity_Direction {
            X_Extremity = 0,
            Y_Extremity = 1
        };

        template<Extremity_Direction D, typename OutF>
        void bezier_extremities(const CubicBezier &bt, OutF f) {
            static_assert(D == 0 || D == 1);

            //quadratic coefficients
            double a = (-get<D>(bt.p0) + 3 * get<D>(bt.p1) + -3 * get<D>(bt.p2) + get<D>(bt.p3));
            double b = 2 * (get<D>(bt.p0) - 2 * get<D>(bt.p1) + get<D>(bt.p2));
            double c = get<D>(bt.p1) - get<D>(bt.p0);

            std::pair<double, double> res{};
            switch (directsolvers::solve_quadratic(c, b, a, res)) {
                case 1:
                    if (unit_inter(res.first)) {
                        f(res.first);
                    }
                    break;
                case 2:
                    if (unit_inter(res.first)) {
                        f(res.first);
                    }
                    if (unit_inter(res.second)) {
                        f(res.second);
                    }
                    break;
                default:
                    return;
            }
        }

        //returns sorted t values ti of a bezier such that each curve subinterval
        // [t_i, t_i+1] is weakly monotonic (increasing/decreasing) in the x and in the y
        // direction. Only inner values (different from 0 and 1) are returned.
        // Note that there can be max. 5 subcurves, which follows from the fact
        // that there are max 4 roots.
        template<typename OutF>
        void bezier_monotonic_split(const CubicBezier &bt, OutF f, double abstol = 1e-10) {

            if ((in_box(bt.p0, bt.p3, bt.p1) || bt.p0 == bt.p1)
                && (in_box(bt.p0, bt.p3, bt.p2) || bt.p3 == bt.p2)) {
                return;
            }

            struct ExtremityValue {
                double t = 1.5;
                Extremity_Direction direction;
            };

            std::array<ExtremityValue, 4> t_vals{};
            std::size_t num = 0;
            Extremity_Direction d = X_Extremity;

            auto t_report = [&t_vals, &num, &d](double t) {
                t_vals[num++] = {t, d};
            };

            bezier_extremities<X_Extremity>(bt, t_report);
            d = Y_Extremity;
            bezier_extremities<Y_Extremity>(bt, t_report);

            std::sort(t_vals.begin(), t_vals.end(),
                      [](const ExtremityValue &a, const ExtremityValue &b) { return a.t < b.t; });

            for (std::size_t i = 0; i < num; ++i) {
                // we want values strictly inside the curve interval. What is more, in the case where
                // a control point_ overlaps with an endpoint, the derivative is also 0, even though it is not
                // an extrema.
                if ((t_vals[i].t < abstol) || (t_vals[i].t + abstol > 1)) {
                    continue;
                }
                f(t_vals[i].t, t_vals[i].direction);
            }
        }

        bool in_box_special(const Segment &seg, const Point2d &p) {
            bool x_ok = in_range_closed(std::min(seg.first.x(), seg.second.x()),
                                        std::max(seg.first.x(), seg.second.x()), p.x());
            bool y_ok = in_range_closed(std::min(seg.first.y(), seg.second.y()),
                                        std::max(seg.first.y(), seg.second.y()), p.y());
            return ((x_ok && y_ok)
                    || (seg.first.x() == seg.second.x() && y_ok)
                    || (seg.first.y() == seg.second.y() && x_ok)
            );
        }

        template<typename IntersectionFunctor>
        void line_bezier_inter_impl(const Segment &seg, const CubicBezier &c,
                                    IntersectionFunctor &inter, double abstol = 1e-10, double cubic_tol = 1e-9) {

            //robustness: we first check if we have some overlapping points/points that lie on the segment.
            //Then we can use exact t=0, 1 and ignore these cases later.
            bool overlapping_start = c.p0 == seg.first || c.p0 == seg.second,
                    overlapping_end = c.p3 == seg.first || c.p3 == seg.second;

            std::size_t start_offset = overlapping_start, end_offset = overlapping_end;

            auto rotate = axis_align_rotate_vals(seg.first, seg.second);
            auto normalize_f = [rotate, seg](const Point2d &p) -> Point2d {
                return rotate_translate_pt(p, seg.first, seg.first, rotate.first, rotate.second);
            };
            CubicBezier normalized = transform(c, normalize_f);

            auto[a_0, a_1, a_2, a_3] = cubic_line_coeffs<1>(normalized);

            std::array<double, 3> roots{1.5, 1.5, 1.5};
            std::size_t num = 0;
            auto addroot = [&roots, &num, &abstol](double r) {
                if (std::abs(r) < abstol) {
                    if (num == 0 || (roots[num - 1] != 0)) {
                        roots[num++] = 0;
                    }
                    return;
                }
                if ((r > 1 && r < 1 + abstol) || (r < 1 && r + abstol > 1)) {
                    if (num == 0 || (roots[num - 1] != 1)) {
                        roots[num++] = 1;
                    }
                    return;
                }
                if (r >= 0 && r <= 1) {
                    if (num == 0 || (roots[num - 1] != r)) {
                        roots[num++] = r;
                    }
                    return;
                }
            };
            //note that roots are sorted in increasing order
            directsolvers::solve_cubic_real(a_0, a_1, a_2, a_3, addroot, cubic_tol);
            // we take into account overlapping start/end points and points on the segment,
            // to produce a consistent output.
            std::size_t bound = num >= end_offset ? num - end_offset : 0;
            for (std::size_t i = start_offset; i < bound; ++i) {
                double r = roots[i];
                if (in_range_closed(0, 1, r)) {
                    //checking if intersection in segment interval.
                    Point2d mapped = beziermap(c, r);
                    if (in_box_special(seg, mapped)) {
//                        if(make_bbox(seg).strict_contains(mapped)){
                        double segment_t = segment_tval(seg, mapped);
                        inter(segment_t, r, mapped);
                    }
                }
            }
        }

        template<typename IntersectionFunctor>
        void line_bezier_inter(const Segment &seg, const CubicBezier &c,
                               IntersectionFunctor &inter_f, double abstol = 1e-10, double cubic_tol = 1e-9) {

            BBox box{};
            make_hull_bbox(c, box);

            bool nointersect = !make_bbox(seg).weak_overlap(box);
            if (nointersect) {
                return;
            }

            Segment seg2 = seg;
            CubicBezier c2 = c;
            bool seg_reversed, bezier_reversed;
            if ((seg_reversed = !increasing(seg.first, seg.second))) {
                seg2 = {seg.second, seg.first};
            }
            if ((bezier_reversed = !bezier_direction(c))) {
                reverse(c2);
            }
            auto inter_f2 = [&](double t, double u, const Point2d &p) {
                t = seg_reversed ? 1 - t : t;
                u = bezier_reversed ? 1 - u : u;
                inter_f(t, u, p);
            };
            line_bezier_inter_impl(seg2, c2, inter_f2, abstol, cubic_tol);
        }

/*
 *
 *  the remainder of this file is concerned with (cubic) bezier-bezier intersections.
 *
*/

        //defines an ordering between 2 different bezier curves.
        bool bezier_ordering(const CubicBezier &b1, const CubicBezier &b2) {
            double area1 = control_poly_area(b1);
            double area2 = control_poly_area(b2);
            if (area1 != area2) {
                return area1 < area2;
            }
            if (b1.p0 != b2.p0) {
                return increasing(b1.p0, b2.p0);
            }
            if (b1.p1 != b2.p1) {
                return increasing(b1.p1, b2.p1);
            }
            if (b1.p2 != b2.p2) {
                return increasing(b1.p2, b2.p2);
            }
            return increasing(b1.p3, b2.p3);
        }

        double determinant3(double a, double b, double c,
                            double d, double e, double f,
                            double g, double h, double i) {
            using namespace directsolvers;
            return a * diff_of_products(e, i, f, h)
                   + b * diff_of_products(f, g, d, i)
                   + c * diff_of_products(d, h, e, g);
        }

        std::array<double, 3> determinant_coeffs(double a, double b, double c, double d) {
            return std::array<double, 3>{(b - d), (-a + c), directsolvers::diff_of_products(a, d, b, c)};
        }

        // a simple functor which maps a point to the parametric interval
        // using a rational function
        template<typename T>
        class maptoT {
            T inverta = 0;
            T invertb = 1;
            std::array<T, 3> a;
            std::array<T, 3> b;
        public:
            maptoT(std::array<T, 3> a, std::array<T, 3> b, bool isinverted) :
                    a(a), b(b) {
                if (isinverted) {
                    invertb = -1;
                    inverta = 1;
                }
            }

            T operator()(T x, T y) {
                return inverta + invertb * (a[0] * x + a[1] * y + a[2]) / (b[0] * x + b[1] * y + b[2]);
            }
        };

        template<typename collinearF = IsCollinear>
        maptoT<double> curveinverter(CubicBezier c, collinearF f = {}) {
            bool directionInverted = false;
            if ((directionInverted = f(c.p1, c.p2, c.p3))) {
                reverse(c);
            }

            auto mult_c = [](double c, const std::array<double, 3> &a) -> std::array<double, 3> {
                return {a[0] * c, a[1] * c, a[2] * c};
            };

            auto l31 = mult_c(3.0, determinant_coeffs(c.p3.x(), c.p3.y(), c.p1.x(), c.p1.y()));
            auto l30 = determinant_coeffs(c.p3.x(), c.p3.y(), c.p0.x(), c.p0.y());
            auto l21 = mult_c(9.0, determinant_coeffs(c.p2.x(), c.p2.y(), c.p1.x(), c.p1.y()));
            auto l20 = mult_c(3.0, determinant_coeffs(c.p2.x(), c.p2.y(), c.p0.x(), c.p0.y()));
            auto l10 = mult_c(3.0, determinant_coeffs(c.p1.x(), c.p1.y(), c.p0.x(), c.p0.y()));

            double d = 3.0 * determinant3(c.p1.x(), c.p1.y(), 1, c.p2.x(),
                                          c.p2.y(), 1, c.p3.x(), c.p3.y(), 1);

            double c1 = determinant3(c.p0.x(), c.p0.y(), 1, c.p1.x(), c.p1.y(), 1,
                                     c.p3.x(), c.p3.y(), 1) / d;
            double c2 = -1.0 * determinant3(c.p0.x(), c.p0.y(), 1, c.p2.x(),
                                            c.p2.y(), 1, c.p3.x(), c.p3.y(), 1) / d;

            std::array<double, 3> num_coeffs{}, den_coeffs{};
            auto compute_num = [&](std::size_t i) -> double {
                return (c1 * l30[i]) + (c2 * l20[i]) + l10[i];
            };
            auto compute_den = [&](std::size_t i) -> double {
                return num_coeffs[i] - (c2 * (l30[i] + l21[i]) + l20[i] + (c1 * l31[i]));
            };
            num_coeffs[0] = compute_num(0);
            num_coeffs[1] = compute_num(1);
            num_coeffs[2] = compute_num(2);
            den_coeffs[0] = compute_den(0);
            den_coeffs[1] = compute_den(1);
            den_coeffs[2] = compute_den(2);

            maptoT out{num_coeffs, den_coeffs, directionInverted};
            return out;
        }

        template<typename T>
        std::array<T, 10>
        generate_coefficients( const T &b0x, const T &b0y, const T &b1x, const T &b1y,
                               const T &b2x, const T &b2y, const T &b3x, const T &b3y,
                               const T &px1, const T &py1, const T &px2, const T &py2, const T &px3, const T &py3) noexcept {
            auto[ax, bx, cx, dx]
            = cubic_line_coeffs(b0x, b1x, b2x, b3x);
            auto[ay, by, cy, dy]
            = cubic_line_coeffs(b0y, b1y, b2y, b3y);

            // note: the following code has been automatically generated.

            auto Power = [](const T &t, const T &v) -> T {
                if (v == 2) return t * t;
                return t * t * t;
            };

            T tmp1 = 3*px1-3*px2+px3;
            T tmp2 = (3*py1-3*py2+py3);

            // clang-format off

            T c0=Power(ay,3)*Power(tmp1,3)-3*Power(ay,2)*(18*Power(px1,3)*py3+ax*Power(tmp1,2)*tmp2-3*px2*(Power(px3,2)*py1-3*px2*px3*py2+3*Power(px2,2)*py3)+3*px1*(2*Power(px3,2)*(3*py1-py2)+9*Power(px2,2)*(py1+py3)+3*px2*px3*(-3*py1-3*py2+py3))-9*Power(px1,2)*(2*px3*(py1-3*py2+py3)+3*px2*(py2+py3)))+3*ay*(Power(ax,2)*(tmp1)*Power(3*py1-3*py2+py3,2)+9*px1*(Power(px3,2)*Power(py1,2)+py3*(3*Power(px2,2)*py1-3*px1*px2*py2+Power(px1,2)*py3)+px3*(-3*px2*py1*py2+3*px1*Power(py2,2)-2*px1*py1*py3))+3*ax*(3*Power(px3,2)*py1*(2*py1-py2)+Power(px2,2)*(9*Power(py1,2)+9*py1*py3-6*py2*py3)+Power(px1,2)*(-9*Power(py2,2)+9*py2*py3+6*(2*py1-py3)*py3)-px1*px3*(12*Power(py1,2)-27*py1*py2+py2*(9*py2+py3))+px2*(3*px1*py3*(-9*py1+3*py2+py3)+px3*(-9*Power(py1,2)-9*py1*py2+6*Power(py2,2)+py1*py3))))-ax*(Power(ax,2)*Power(3*py1-3*py2+py3,3)+27*py1*(Power(px3,2)*Power(py1,2)+py3*(3*Power(px2,2)*py1-3*px1*px2*py2+Power(px1,2)*py3)+px3*(-3*px2*py1*py2+3*px1*Power(py2,2)-2*px1*py1*py3))-9*ax*(3*px3*(2*py1-py2)*(Power(py1,2)+Power(py2,2)-py1*(py2+py3))+px2*(-9*Power(py1,2)*(py2-2*py3)+3*Power(py2,2)*py3-py1*py3*(9*py2+2*py3))-px1*(6*Power(py1,2)*py3+py2*Power(py3,2)+py1*(-9*Power(py2,2)+9*py2*py3-6*Power(py3,2)))));T c1=-3*(Power(ay,2)*Power(tmp1,2)*(-(by*(tmp1))+bx*tmp2)+Power(ax,2)*Power(3*py1-3*py2+py3,2)*(-(by*(tmp1))+bx*tmp2)-9*(by*px1-bx*py1)*(Power(px3,2)*Power(py1,2)+py3*(3*Power(px2,2)*py1-3*px1*px2*py2+Power(px1,2)*py3)+px3*(-3*px2*py1*py2+3*px1*Power(py2,2)-2*px1*py1*py3))-3*ax*by*(3*Power(px3,2)*py1*(2*py1-py2)+Power(px2,2)*(9*Power(py1,2)+9*py1*py3-6*py2*py3)+Power(px1,2)*(-9*Power(py2,2)+9*py2*py3+6*(2*py1-py3)*py3)-px1*px3*(12*Power(py1,2)-27*py1*py2+py2*(9*py2+py3))+px2*(3*px1*py3*(-9*py1+3*py2+py3)+px3*(-9*Power(py1,2)-9*py1*py2+6*Power(py2,2)+py1*py3)))+6*ax*bx*(-3*px3*(2*py1-py2)*(Power(py1,2)+Power(py2,2)-py1*(py2+py3))+px2*(9*Power(py1,2)*(py2-2*py3)-3*Power(py2,2)*py3+py1*py3*(9*py2+2*py3))+px1*(6*Power(py1,2)*py3+py2*Power(py3,2)+py1*(-9*Power(py2,2)+9*py2*py3-6*Power(py3,2))))+ay*(2*ax*(tmp1)*tmp2*(by*(tmp1)-bx*tmp2)+6*by*(6*Power(px1,3)*py3-px2*(Power(px3,2)*py1-3*px2*px3*py2+3*Power(px2,2)*py3)+px1*(2*Power(px3,2)*(3*py1-py2)+9*Power(px2,2)*(py1+py3)+3*px2*px3*(-3*py1-3*py2+py3))-3*Power(px1,2)*(2*px3*(py1-3*py2+py3)+3*px2*(py2+py3)))-3*bx*(3*Power(px3,2)*py1*(2*py1-py2)+Power(px2,2)*(9*Power(py1,2)+9*py1*py3-6*py2*py3)+Power(px1,2)*(-9*Power(py2,2)+9*py2*py3+6*(2*py1-py3)*py3)-px1*px3*(12*Power(py1,2)-27*py1*py2+py2*(9*py2+py3))+px2*(3*px1*py3*(-9*py1+3*py2+py3)+px3*(-9*Power(py1,2)-9*py1*py2+6*Power(py2,2)+py1*py3)))));T c2=-3*(Power(ay,2)*Power(tmp1,2)*(-(cy*(tmp1))+cx*tmp2)+Power(ax,2)*Power(3*py1-3*py2+py3,2)*(-(cy*(tmp1))+cx*tmp2)-ay*(Power(by,2)*Power(tmp1,3)-54*cy*px1*Power(px2,2)*py1+36*cy*Power(px1,2)*px3*py1+54*cy*px1*px2*px3*py1-36*cy*px1*Power(px3,2)*py1+6*cy*px2*Power(px3,2)*py1+27*Power(bx,2)*px1*Power(py1,2)-27*Power(bx,2)*px2*Power(py1,2)+27*cx*Power(px2,2)*Power(py1,2)+9*Power(bx,2)*px3*Power(py1,2)-36*cx*px1*px3*Power(py1,2)-27*cx*px2*px3*Power(py1,2)+18*cx*Power(px3,2)*Power(py1,2)+54*cy*Power(px1,2)*px2*py2-108*cy*Power(px1,2)*px3*py2+54*cy*px1*px2*px3*py2-18*cy*Power(px2,2)*px3*py2+12*cy*px1*Power(px3,2)*py2-54*Power(bx,2)*px1*py1*py2+54*Power(bx,2)*px2*py1*py2-18*Power(bx,2)*px3*py1*py2+81*cx*px1*px3*py1*py2-27*cx*px2*px3*py1*py2-9*cx*Power(px3,2)*py1*py2+27*Power(bx,2)*px1*Power(py2,2)-27*cx*Power(px1,2)*Power(py2,2)-27*Power(bx,2)*px2*Power(py2,2)+9*Power(bx,2)*px3*Power(py2,2)-27*cx*px1*px3*Power(py2,2)+18*cx*px2*px3*Power(py2,2)-36*cy*Power(px1,3)*py3+54*cy*Power(px1,2)*px2*py3-54*cy*px1*Power(px2,2)*py3+18*cy*Power(px2,3)*py3+36*cy*Power(px1,2)*px3*py3-18*cy*px1*px2*px3*py3+18*Power(bx,2)*px1*py1*py3+36*cx*Power(px1,2)*py1*py3-18*Power(bx,2)*px2*py1*py3-81*cx*px1*px2*py1*py3+27*cx*Power(px2,2)*py1*py3+6*Power(bx,2)*px3*py1*py3+3*cx*px2*px3*py1*py3-18*Power(bx,2)*px1*py2*py3+27*cx*Power(px1,2)*py2*py3+18*Power(bx,2)*px2*py2*py3+27*cx*px1*px2*py2*py3-18*cx*Power(px2,2)*py2*py3-6*Power(bx,2)*px3*py2*py3-3*cx*px1*px3*py2*py3+3*Power(bx,2)*px1*Power(py3,2)-18*cx*Power(px1,2)*Power(py3,2)-3*Power(bx,2)*px2*Power(py3,2)+9*cx*px1*px2*Power(py3,2)+Power(bx,2)*px3*Power(py3,2)-2*bx*by*Power(tmp1,2)*tmp2-2*ax*(tmp1)*tmp2*(cy*(tmp1)-cx*tmp2))+3*(-3*cy*px1*Power(px3,2)*Power(py1,2)-6*Power(bx,2)*px3*Power(py1,3)+3*cx*Power(px3,2)*Power(py1,3)+9*cy*px1*px2*px3*py1*py2+9*Power(bx,2)*px2*Power(py1,2)*py2+9*Power(bx,2)*px3*Power(py1,2)*py2-9*cx*px2*px3*Power(py1,2)*py2-9*cy*Power(px1,2)*px3*Power(py2,2)-9*Power(bx,2)*px1*py1*Power(py2,2)-9*Power(bx,2)*px3*py1*Power(py2,2)+9*cx*px1*px3*py1*Power(py2,2)+3*Power(bx,2)*px3*Power(py2,3)-9*cy*px1*Power(px2,2)*py1*py3+6*cy*Power(px1,2)*px3*py1*py3+6*Power(bx,2)*px1*Power(py1,2)*py3-18*Power(bx,2)*px2*Power(py1,2)*py3+9*cx*Power(px2,2)*Power(py1,2)*py3+6*Power(bx,2)*px3*Power(py1,2)*py3-6*cx*px1*px3*Power(py1,2)*py3+9*cy*Power(px1,2)*px2*py2*py3+9*Power(bx,2)*px1*py1*py2*py3+9*Power(bx,2)*px2*py1*py2*py3-9*cx*px1*px2*py1*py2*py3-3*Power(bx,2)*px3*py1*py2*py3-3*Power(bx,2)*px2*Power(py2,2)*py3-3*cy*Power(px1,3)*Power(py3,2)-6*Power(bx,2)*px1*py1*Power(py3,2)+3*cx*Power(px1,2)*py1*Power(py3,2)+2*Power(bx,2)*px2*py1*Power(py3,2)+Power(bx,2)*px1*py2*Power(py3,2)+Power(by,2)*(6*Power(px1,3)*py3-px2*(Power(px3,2)*py1-3*px2*px3*py2+3*Power(px2,2)*py3)+px1*(2*Power(px3,2)*(3*py1-py2)+9*Power(px2,2)*(py1+py3)+3*px2*px3*(-3*py1-3*py2+py3))-3*Power(px1,2)*(2*px3*(py1-3*py2+py3)+3*px2*(py2+py3)))+bx*by*(3*Power(px3,2)*py1*(-2*py1+py2)+Power(px2,2)*(-9*Power(py1,2)-9*py1*py3+6*py2*py3)+3*Power(px1,2)*(3*Power(py2,2)-3*py2*py3+2*py3*(-2*py1+py3))+px1*px3*(12*Power(py1,2)-27*py1*py2+py2*(9*py2+py3))+px2*(3*px1*(9*py1-3*py2-py3)*py3+px3*(9*Power(py1,2)+9*py1*py2-6*Power(py2,2)-py1*py3))))+ax*(27*Power(bx,2)*Power(py1,3)-36*cx*px3*Power(py1,3)-81*Power(bx,2)*Power(py1,2)*py2+54*cx*px2*Power(py1,2)*py2+54*cx*px3*Power(py1,2)*py2+81*Power(bx,2)*py1*Power(py2,2)-54*cx*px1*py1*Power(py2,2)-54*cx*px3*py1*Power(py2,2)-27*Power(bx,2)*Power(py2,3)+18*cx*px3*Power(py2,3)+27*Power(bx,2)*Power(py1,2)*py3+36*cx*px1*Power(py1,2)*py3-108*cx*px2*Power(py1,2)*py3+36*cx*px3*Power(py1,2)*py3-54*Power(bx,2)*py1*py2*py3+54*cx*px1*py1*py2*py3+54*cx*px2*py1*py2*py3-18*cx*px3*py1*py2*py3+27*Power(bx,2)*Power(py2,2)*py3-18*cx*px2*Power(py2,2)*py3+9*Power(bx,2)*py1*Power(py3,2)-36*cx*px1*py1*Power(py3,2)+12*cx*px2*py1*Power(py3,2)-9*Power(bx,2)*py2*Power(py3,2)+6*cx*px1*py2*Power(py3,2)+Power(bx,2)*Power(py3,3)+Power(by,2)*Power(tmp1,2)*tmp2-2*bx*by*(tmp1)*Power(3*py1-3*py2+py3,2)-3*cy*(3*Power(px3,2)*py1*(2*py1-py2)+Power(px2,2)*(9*Power(py1,2)+9*py1*py3-6*py2*py3)+Power(px1,2)*(-9*Power(py2,2)+9*py2*py3+6*(2*py1-py3)*py3)-px1*px3*(12*Power(py1,2)-27*py1*py2+py2*(9*py2+py3))+px2*(3*px1*py3*(-9*py1+3*py2+py3)+px3*(-9*Power(py1,2)-9*py1*py2+6*Power(py2,2)+py1*py3)))));T c3=+(Power(by,3)*Power(tmp1,3)+162*ax*bx*cy*px1*Power(py1,2)+81*Power(ax,2)*dy*px1*Power(py1,2)-162*ax*bx*cy*px2*Power(py1,2)-81*Power(ax,2)*dy*px2*Power(py1,2)+81*bx*cy*Power(px2,2)*Power(py1,2)+81*ax*dy*Power(px2,2)*Power(py1,2)+54*ax*bx*cy*px3*Power(py1,2)+27*Power(ax,2)*dy*px3*Power(py1,2)-108*bx*cy*px1*px3*Power(py1,2)-108*ax*dy*px1*px3*Power(py1,2)-81*bx*cy*px2*px3*Power(py1,2)-81*ax*dy*px2*px3*Power(py1,2)+54*bx*cy*Power(px3,2)*Power(py1,2)+54*ax*dy*Power(px3,2)*Power(py1,2)+27*dy*px1*Power(px3,2)*Power(py1,2)-27*Power(bx,3)*Power(py1,3)-162*ax*bx*cx*Power(py1,3)-81*Power(ax,2)*dx*Power(py1,3)+108*bx*cx*px3*Power(py1,3)+108*ax*dx*px3*Power(py1,3)-27*dx*Power(px3,2)*Power(py1,3)-324*ax*bx*cy*px1*py1*py2-162*Power(ax,2)*dy*px1*py1*py2+324*ax*bx*cy*px2*py1*py2+162*Power(ax,2)*dy*px2*py1*py2-108*ax*bx*cy*px3*py1*py2-54*Power(ax,2)*dy*px3*py1*py2+243*bx*cy*px1*px3*py1*py2+243*ax*dy*px1*px3*py1*py2-81*bx*cy*px2*px3*py1*py2-81*ax*dy*px2*px3*py1*py2-81*dy*px1*px2*px3*py1*py2-27*bx*cy*Power(px3,2)*py1*py2-27*ax*dy*Power(px3,2)*py1*py2+81*Power(bx,3)*Power(py1,2)*py2+486*ax*bx*cx*Power(py1,2)*py2+243*Power(ax,2)*dx*Power(py1,2)*py2-162*bx*cx*px2*Power(py1,2)*py2-162*ax*dx*px2*Power(py1,2)*py2-162*bx*cx*px3*Power(py1,2)*py2-162*ax*dx*px3*Power(py1,2)*py2+81*dx*px2*px3*Power(py1,2)*py2+162*ax*bx*cy*px1*Power(py2,2)+81*Power(ax,2)*dy*px1*Power(py2,2)-81*bx*cy*Power(px1,2)*Power(py2,2)-81*ax*dy*Power(px1,2)*Power(py2,2)-162*ax*bx*cy*px2*Power(py2,2)-81*Power(ax,2)*dy*px2*Power(py2,2)+54*ax*bx*cy*px3*Power(py2,2)+27*Power(ax,2)*dy*px3*Power(py2,2)-81*bx*cy*px1*px3*Power(py2,2)-81*ax*dy*px1*px3*Power(py2,2)+81*dy*Power(px1,2)*px3*Power(py2,2)+54*bx*cy*px2*px3*Power(py2,2)+54*ax*dy*px2*px3*Power(py2,2)-81*Power(bx,3)*py1*Power(py2,2)-486*ax*bx*cx*py1*Power(py2,2)-243*Power(ax,2)*dx*py1*Power(py2,2)+162*bx*cx*px1*py1*Power(py2,2)+162*ax*dx*px1*py1*Power(py2,2)+162*bx*cx*px3*py1*Power(py2,2)+162*ax*dx*px3*py1*Power(py2,2)-81*dx*px1*px3*py1*Power(py2,2)+27*Power(bx,3)*Power(py2,3)+162*ax*bx*cx*Power(py2,3)+81*Power(ax,2)*dx*Power(py2,3)-54*bx*cx*px3*Power(py2,3)-54*ax*dx*px3*Power(py2,3)+108*ax*bx*cy*px1*py1*py3+54*Power(ax,2)*dy*px1*py1*py3+108*bx*cy*Power(px1,2)*py1*py3+108*ax*dy*Power(px1,2)*py1*py3-108*ax*bx*cy*px2*py1*py3-54*Power(ax,2)*dy*px2*py1*py3-243*bx*cy*px1*px2*py1*py3-243*ax*dy*px1*px2*py1*py3+81*bx*cy*Power(px2,2)*py1*py3+81*ax*dy*Power(px2,2)*py1*py3+81*dy*px1*Power(px2,2)*py1*py3+36*ax*bx*cy*px3*py1*py3+18*Power(ax,2)*dy*px3*py1*py3-54*dy*Power(px1,2)*px3*py1*py3+9*bx*cy*px2*px3*py1*py3+9*ax*dy*px2*px3*py1*py3-27*Power(bx,3)*Power(py1,2)*py3-162*ax*bx*cx*Power(py1,2)*py3-81*Power(ax,2)*dx*Power(py1,2)*py3-108*bx*cx*px1*Power(py1,2)*py3-108*ax*dx*px1*Power(py1,2)*py3+324*bx*cx*px2*Power(py1,2)*py3+324*ax*dx*px2*Power(py1,2)*py3-81*dx*Power(px2,2)*Power(py1,2)*py3-108*bx*cx*px3*Power(py1,2)*py3-108*ax*dx*px3*Power(py1,2)*py3+54*dx*px1*px3*Power(py1,2)*py3-108*ax*bx*cy*px1*py2*py3-54*Power(ax,2)*dy*px1*py2*py3+81*bx*cy*Power(px1,2)*py2*py3+81*ax*dy*Power(px1,2)*py2*py3+108*ax*bx*cy*px2*py2*py3+54*Power(ax,2)*dy*px2*py2*py3+81*bx*cy*px1*px2*py2*py3+81*ax*dy*px1*px2*py2*py3-81*dy*Power(px1,2)*px2*py2*py3-54*bx*cy*Power(px2,2)*py2*py3-54*ax*dy*Power(px2,2)*py2*py3-36*ax*bx*cy*px3*py2*py3-18*Power(ax,2)*dy*px3*py2*py3-9*bx*cy*px1*px3*py2*py3-9*ax*dy*px1*px3*py2*py3+54*Power(bx,3)*py1*py2*py3+324*ax*bx*cx*py1*py2*py3+162*Power(ax,2)*dx*py1*py2*py3-162*bx*cx*px1*py1*py2*py3-162*ax*dx*px1*py1*py2*py3-162*bx*cx*px2*py1*py2*py3-162*ax*dx*px2*py1*py2*py3+81*dx*px1*px2*py1*py2*py3+54*bx*cx*px3*py1*py2*py3+54*ax*dx*px3*py1*py2*py3-27*Power(bx,3)*Power(py2,2)*py3-162*ax*bx*cx*Power(py2,2)*py3-81*Power(ax,2)*dx*Power(py2,2)*py3+54*bx*cx*px2*Power(py2,2)*py3+54*ax*dx*px2*Power(py2,2)*py3+18*ax*bx*cy*px1*Power(py3,2)+9*Power(ax,2)*dy*px1*Power(py3,2)-54*bx*cy*Power(px1,2)*Power(py3,2)-54*ax*dy*Power(px1,2)*Power(py3,2)+27*dy*Power(px1,3)*Power(py3,2)-18*ax*bx*cy*px2*Power(py3,2)-9*Power(ax,2)*dy*px2*Power(py3,2)+27*bx*cy*px1*px2*Power(py3,2)+27*ax*dy*px1*px2*Power(py3,2)+6*ax*bx*cy*px3*Power(py3,2)+3*Power(ax,2)*dy*px3*Power(py3,2)-9*Power(bx,3)*py1*Power(py3,2)-54*ax*bx*cx*py1*Power(py3,2)-27*Power(ax,2)*dx*py1*Power(py3,2)+108*bx*cx*px1*py1*Power(py3,2)+108*ax*dx*px1*py1*Power(py3,2)-27*dx*Power(px1,2)*py1*Power(py3,2)-36*bx*cx*px2*py1*Power(py3,2)-36*ax*dx*px2*py1*Power(py3,2)+9*Power(bx,3)*py2*Power(py3,2)+54*ax*bx*cx*py2*Power(py3,2)+27*Power(ax,2)*dx*py2*Power(py3,2)-18*bx*cx*px1*py2*Power(py3,2)-18*ax*dx*px1*py2*Power(py3,2)-Power(bx,3)*Power(py3,3)-6*ax*bx*cx*Power(py3,3)-3*Power(ax,2)*dx*Power(py3,3)-3*bx*Power(by,2)*Power(tmp1,2)*tmp2+3*Power(ay,2)*Power(tmp1,2)*(dy*(tmp1)-dx*tmp2)+3*by*(-54*cy*px1*Power(px2,2)*py1+36*cy*Power(px1,2)*px3*py1+54*cy*px1*px2*px3*py1-36*cy*px1*Power(px3,2)*py1+6*cy*px2*Power(px3,2)*py1+27*Power(bx,2)*px1*Power(py1,2)-27*Power(bx,2)*px2*Power(py1,2)+27*cx*Power(px2,2)*Power(py1,2)+9*Power(bx,2)*px3*Power(py1,2)-36*cx*px1*px3*Power(py1,2)-27*cx*px2*px3*Power(py1,2)+18*cx*Power(px3,2)*Power(py1,2)+54*cy*Power(px1,2)*px2*py2-108*cy*Power(px1,2)*px3*py2+54*cy*px1*px2*px3*py2-18*cy*Power(px2,2)*px3*py2+12*cy*px1*Power(px3,2)*py2-54*Power(bx,2)*px1*py1*py2+54*Power(bx,2)*px2*py1*py2-18*Power(bx,2)*px3*py1*py2+81*cx*px1*px3*py1*py2-27*cx*px2*px3*py1*py2-9*cx*Power(px3,2)*py1*py2+27*Power(bx,2)*px1*Power(py2,2)-27*cx*Power(px1,2)*Power(py2,2)-27*Power(bx,2)*px2*Power(py2,2)+9*Power(bx,2)*px3*Power(py2,2)-27*cx*px1*px3*Power(py2,2)+18*cx*px2*px3*Power(py2,2)-36*cy*Power(px1,3)*py3+54*cy*Power(px1,2)*px2*py3-54*cy*px1*Power(px2,2)*py3+18*cy*Power(px2,3)*py3+36*cy*Power(px1,2)*px3*py3-18*cy*px1*px2*px3*py3+18*Power(bx,2)*px1*py1*py3+36*cx*Power(px1,2)*py1*py3-18*Power(bx,2)*px2*py1*py3-81*cx*px1*px2*py1*py3+27*cx*Power(px2,2)*py1*py3+6*Power(bx,2)*px3*py1*py3+3*cx*px2*px3*py1*py3-18*Power(bx,2)*px1*py2*py3+27*cx*Power(px1,2)*py2*py3+18*Power(bx,2)*px2*py2*py3+27*cx*px1*px2*py2*py3-18*cx*Power(px2,2)*py2*py3-6*Power(bx,2)*px3*py2*py3-3*cx*px1*px3*py2*py3+3*Power(bx,2)*px1*Power(py3,2)-18*cx*Power(px1,2)*Power(py3,2)-3*Power(bx,2)*px2*Power(py3,2)+9*cx*px1*px2*Power(py3,2)+Power(bx,2)*px3*Power(py3,2)+2*ay*Power(tmp1,2)*(cy*(tmp1)-cx*tmp2)-2*ax*(tmp1)*tmp2*(cy*(tmp1)-cx*tmp2))-3*ay*(2*bx*(tmp1)*tmp2*(cy*(tmp1)-cx*tmp2)+2*ax*(tmp1)*tmp2*(dy*(tmp1)-dx*tmp2)+6*dy*(6*Power(px1,3)*py3-px2*(Power(px3,2)*py1-3*px2*px3*py2+3*Power(px2,2)*py3)+px1*(2*Power(px3,2)*(3*py1-py2)+9*Power(px2,2)*(py1+py3)+3*px2*px3*(-3*py1-3*py2+py3))-3*Power(px1,2)*(2*px3*(py1-3*py2+py3)+3*px2*(py2+py3)))-3*dx*(3*Power(px3,2)*py1*(2*py1-py2)+Power(px2,2)*(9*Power(py1,2)+9*py1*py3-6*py2*py3)+Power(px1,2)*(-9*Power(py2,2)+9*py2*py3+6*(2*py1-py3)*py3)-px1*px3*(12*Power(py1,2)-27*py1*py2+py2*(9*py2+py3))+px2*(3*px1*py3*(-9*py1+3*py2+py3)+px3*(-9*Power(py1,2)-9*py1*py2+6*Power(py2,2)+py1*py3)))));T c4=-3*(27*ax*Power(cy,2)*Power(px1,2)*py1-54*ax*Power(cy,2)*px1*px2*py1+27*ax*Power(cy,2)*Power(px2,2)*py1+27*Power(cy,2)*px1*Power(px2,2)*py1+18*ax*Power(cy,2)*px1*px3*py1-18*Power(cy,2)*Power(px1,2)*px3*py1-18*ax*Power(cy,2)*px2*px3*py1-27*Power(cy,2)*px1*px2*px3*py1+3*ax*Power(cy,2)*Power(px3,2)*py1+18*Power(cy,2)*px1*Power(px3,2)*py1-3*Power(cy,2)*px2*Power(px3,2)*py1-27*Power(bx,2)*cy*px1*Power(py1,2)-54*ax*cx*cy*px1*Power(py1,2)-54*ax*bx*dy*px1*Power(py1,2)+27*Power(bx,2)*cy*px2*Power(py1,2)+54*ax*cx*cy*px2*Power(py1,2)+54*ax*bx*dy*px2*Power(py1,2)-27*cx*cy*Power(px2,2)*Power(py1,2)-27*bx*dy*Power(px2,2)*Power(py1,2)-9*Power(bx,2)*cy*px3*Power(py1,2)-18*ax*cx*cy*px3*Power(py1,2)-18*ax*bx*dy*px3*Power(py1,2)+36*cx*cy*px1*px3*Power(py1,2)+36*bx*dy*px1*px3*Power(py1,2)+27*cx*cy*px2*px3*Power(py1,2)+27*bx*dy*px2*px3*Power(py1,2)-18*cx*cy*Power(px3,2)*Power(py1,2)-18*bx*dy*Power(px3,2)*Power(py1,2)+27*Power(bx,2)*cx*Power(py1,3)+27*ax*Power(cx,2)*Power(py1,3)+54*ax*bx*dx*Power(py1,3)-18*Power(cx,2)*px3*Power(py1,3)-36*bx*dx*px3*Power(py1,3)-27*ax*Power(cy,2)*Power(px1,2)*py2+54*ax*Power(cy,2)*px1*px2*py2-27*Power(cy,2)*Power(px1,2)*px2*py2-27*ax*Power(cy,2)*Power(px2,2)*py2-18*ax*Power(cy,2)*px1*px3*py2+54*Power(cy,2)*Power(px1,2)*px3*py2+18*ax*Power(cy,2)*px2*px3*py2-27*Power(cy,2)*px1*px2*px3*py2+9*Power(cy,2)*Power(px2,2)*px3*py2-3*ax*Power(cy,2)*Power(px3,2)*py2-6*Power(cy,2)*px1*Power(px3,2)*py2+54*Power(bx,2)*cy*px1*py1*py2+108*ax*cx*cy*px1*py1*py2+108*ax*bx*dy*px1*py1*py2-54*Power(bx,2)*cy*px2*py1*py2-108*ax*cx*cy*px2*py1*py2-108*ax*bx*dy*px2*py1*py2+18*Power(bx,2)*cy*px3*py1*py2+36*ax*cx*cy*px3*py1*py2+36*ax*bx*dy*px3*py1*py2-81*cx*cy*px1*px3*py1*py2-81*bx*dy*px1*px3*py1*py2+27*cx*cy*px2*px3*py1*py2+27*bx*dy*px2*px3*py1*py2+9*cx*cy*Power(px3,2)*py1*py2+9*bx*dy*Power(px3,2)*py1*py2-81*Power(bx,2)*cx*Power(py1,2)*py2-81*ax*Power(cx,2)*Power(py1,2)*py2-162*ax*bx*dx*Power(py1,2)*py2+27*Power(cx,2)*px2*Power(py1,2)*py2+54*bx*dx*px2*Power(py1,2)*py2+27*Power(cx,2)*px3*Power(py1,2)*py2+54*bx*dx*px3*Power(py1,2)*py2-27*Power(bx,2)*cy*px1*Power(py2,2)-54*ax*cx*cy*px1*Power(py2,2)-54*ax*bx*dy*px1*Power(py2,2)+27*cx*cy*Power(px1,2)*Power(py2,2)+27*bx*dy*Power(px1,2)*Power(py2,2)+27*Power(bx,2)*cy*px2*Power(py2,2)+54*ax*cx*cy*px2*Power(py2,2)+54*ax*bx*dy*px2*Power(py2,2)-9*Power(bx,2)*cy*px3*Power(py2,2)-18*ax*cx*cy*px3*Power(py2,2)-18*ax*bx*dy*px3*Power(py2,2)+27*cx*cy*px1*px3*Power(py2,2)+27*bx*dy*px1*px3*Power(py2,2)-18*cx*cy*px2*px3*Power(py2,2)-18*bx*dy*px2*px3*Power(py2,2)+81*Power(bx,2)*cx*py1*Power(py2,2)+81*ax*Power(cx,2)*py1*Power(py2,2)+162*ax*bx*dx*py1*Power(py2,2)-27*Power(cx,2)*px1*py1*Power(py2,2)-54*bx*dx*px1*py1*Power(py2,2)-27*Power(cx,2)*px3*py1*Power(py2,2)-54*bx*dx*px3*py1*Power(py2,2)-27*Power(bx,2)*cx*Power(py2,3)-27*ax*Power(cx,2)*Power(py2,3)-54*ax*bx*dx*Power(py2,3)+9*Power(cx,2)*px3*Power(py2,3)+18*bx*dx*px3*Power(py2,3)+9*ax*Power(cy,2)*Power(px1,2)*py3+18*Power(cy,2)*Power(px1,3)*py3-18*ax*Power(cy,2)*px1*px2*py3-27*Power(cy,2)*Power(px1,2)*px2*py3+9*ax*Power(cy,2)*Power(px2,2)*py3+27*Power(cy,2)*px1*Power(px2,2)*py3-9*Power(cy,2)*Power(px2,3)*py3+6*ax*Power(cy,2)*px1*px3*py3-18*Power(cy,2)*Power(px1,2)*px3*py3-6*ax*Power(cy,2)*px2*px3*py3+9*Power(cy,2)*px1*px2*px3*py3+ax*Power(cy,2)*Power(px3,2)*py3-18*Power(bx,2)*cy*px1*py1*py3-36*ax*cx*cy*px1*py1*py3-36*ax*bx*dy*px1*py1*py3-36*cx*cy*Power(px1,2)*py1*py3-36*bx*dy*Power(px1,2)*py1*py3+18*Power(bx,2)*cy*px2*py1*py3+36*ax*cx*cy*px2*py1*py3+36*ax*bx*dy*px2*py1*py3+81*cx*cy*px1*px2*py1*py3+81*bx*dy*px1*px2*py1*py3-27*cx*cy*Power(px2,2)*py1*py3-27*bx*dy*Power(px2,2)*py1*py3-6*Power(bx,2)*cy*px3*py1*py3-12*ax*cx*cy*px3*py1*py3-12*ax*bx*dy*px3*py1*py3-3*cx*cy*px2*px3*py1*py3-3*bx*dy*px2*px3*py1*py3+27*Power(bx,2)*cx*Power(py1,2)*py3+27*ax*Power(cx,2)*Power(py1,2)*py3+54*ax*bx*dx*Power(py1,2)*py3+18*Power(cx,2)*px1*Power(py1,2)*py3+36*bx*dx*px1*Power(py1,2)*py3-54*Power(cx,2)*px2*Power(py1,2)*py3-108*bx*dx*px2*Power(py1,2)*py3+18*Power(cx,2)*px3*Power(py1,2)*py3+36*bx*dx*px3*Power(py1,2)*py3+18*Power(bx,2)*cy*px1*py2*py3+36*ax*cx*cy*px1*py2*py3+36*ax*bx*dy*px1*py2*py3-27*cx*cy*Power(px1,2)*py2*py3-27*bx*dy*Power(px1,2)*py2*py3-18*Power(bx,2)*cy*px2*py2*py3-36*ax*cx*cy*px2*py2*py3-36*ax*bx*dy*px2*py2*py3-27*cx*cy*px1*px2*py2*py3-27*bx*dy*px1*px2*py2*py3+18*cx*cy*Power(px2,2)*py2*py3+18*bx*dy*Power(px2,2)*py2*py3+6*Power(bx,2)*cy*px3*py2*py3+12*ax*cx*cy*px3*py2*py3+12*ax*bx*dy*px3*py2*py3+3*cx*cy*px1*px3*py2*py3+3*bx*dy*px1*px3*py2*py3-54*Power(bx,2)*cx*py1*py2*py3-54*ax*Power(cx,2)*py1*py2*py3-108*ax*bx*dx*py1*py2*py3+27*Power(cx,2)*px1*py1*py2*py3+54*bx*dx*px1*py1*py2*py3+27*Power(cx,2)*px2*py1*py2*py3+54*bx*dx*px2*py1*py2*py3-9*Power(cx,2)*px3*py1*py2*py3-18*bx*dx*px3*py1*py2*py3+27*Power(bx,2)*cx*Power(py2,2)*py3+27*ax*Power(cx,2)*Power(py2,2)*py3+54*ax*bx*dx*Power(py2,2)*py3-9*Power(cx,2)*px2*Power(py2,2)*py3-18*bx*dx*px2*Power(py2,2)*py3-3*Power(bx,2)*cy*px1*Power(py3,2)-6*ax*cx*cy*px1*Power(py3,2)-6*ax*bx*dy*px1*Power(py3,2)+18*cx*cy*Power(px1,2)*Power(py3,2)+18*bx*dy*Power(px1,2)*Power(py3,2)+3*Power(bx,2)*cy*px2*Power(py3,2)+6*ax*cx*cy*px2*Power(py3,2)+6*ax*bx*dy*px2*Power(py3,2)-9*cx*cy*px1*px2*Power(py3,2)-9*bx*dy*px1*px2*Power(py3,2)-Power(bx,2)*cy*px3*Power(py3,2)-2*ax*cx*cy*px3*Power(py3,2)-2*ax*bx*dy*px3*Power(py3,2)+9*Power(bx,2)*cx*py1*Power(py3,2)+9*ax*Power(cx,2)*py1*Power(py3,2)+18*ax*bx*dx*py1*Power(py3,2)-18*Power(cx,2)*px1*py1*Power(py3,2)-36*bx*dx*px1*py1*Power(py3,2)+6*Power(cx,2)*px2*py1*Power(py3,2)+12*bx*dx*px2*py1*Power(py3,2)-9*Power(bx,2)*cx*py2*Power(py3,2)-9*ax*Power(cx,2)*py2*Power(py3,2)-18*ax*bx*dx*py2*Power(py3,2)+3*Power(cx,2)*px1*py2*Power(py3,2)+6*bx*dx*px1*py2*Power(py3,2)+Power(bx,2)*cx*Power(py3,3)+ax*Power(cx,2)*Power(py3,3)+2*ax*bx*dx*Power(py3,3)+Power(by,2)*Power(tmp1,2)*(-(cy*(tmp1))+cx*tmp2)-by*(-54*ax*dy*Power(px1,2)*py1+108*ax*dy*px1*px2*py1-54*ax*dy*Power(px2,2)*py1-54*dy*px1*Power(px2,2)*py1-36*ax*dy*px1*px3*py1+36*dy*Power(px1,2)*px3*py1+36*ax*dy*px2*px3*py1+54*dy*px1*px2*px3*py1-6*ax*dy*Power(px3,2)*py1-36*dy*px1*Power(px3,2)*py1+6*dy*px2*Power(px3,2)*py1+54*ax*dx*px1*Power(py1,2)-54*ax*dx*px2*Power(py1,2)+27*dx*Power(px2,2)*Power(py1,2)+18*ax*dx*px3*Power(py1,2)-36*dx*px1*px3*Power(py1,2)-27*dx*px2*px3*Power(py1,2)+18*dx*Power(px3,2)*Power(py1,2)+54*ax*dy*Power(px1,2)*py2-108*ax*dy*px1*px2*py2+54*dy*Power(px1,2)*px2*py2+54*ax*dy*Power(px2,2)*py2+36*ax*dy*px1*px3*py2-108*dy*Power(px1,2)*px3*py2-36*ax*dy*px2*px3*py2+54*dy*px1*px2*px3*py2-18*dy*Power(px2,2)*px3*py2+6*ax*dy*Power(px3,2)*py2+12*dy*px1*Power(px3,2)*py2-108*ax*dx*px1*py1*py2+108*ax*dx*px2*py1*py2-36*ax*dx*px3*py1*py2+81*dx*px1*px3*py1*py2-27*dx*px2*px3*py1*py2-9*dx*Power(px3,2)*py1*py2+54*ax*dx*px1*Power(py2,2)-27*dx*Power(px1,2)*Power(py2,2)-54*ax*dx*px2*Power(py2,2)+18*ax*dx*px3*Power(py2,2)-27*dx*px1*px3*Power(py2,2)+18*dx*px2*px3*Power(py2,2)-18*ax*dy*Power(px1,2)*py3-36*dy*Power(px1,3)*py3+36*ax*dy*px1*px2*py3+54*dy*Power(px1,2)*px2*py3-18*ax*dy*Power(px2,2)*py3-54*dy*px1*Power(px2,2)*py3+18*dy*Power(px2,3)*py3-12*ax*dy*px1*px3*py3+36*dy*Power(px1,2)*px3*py3+12*ax*dy*px2*px3*py3-18*dy*px1*px2*px3*py3-2*ax*dy*Power(px3,2)*py3+36*ax*dx*px1*py1*py3+36*dx*Power(px1,2)*py1*py3-36*ax*dx*px2*py1*py3-81*dx*px1*px2*py1*py3+27*dx*Power(px2,2)*py1*py3+12*ax*dx*px3*py1*py3+3*dx*px2*px3*py1*py3-36*ax*dx*px1*py2*py3+27*dx*Power(px1,2)*py2*py3+36*ax*dx*px2*py2*py3+27*dx*px1*px2*py2*py3-18*dx*Power(px2,2)*py2*py3-12*ax*dx*px3*py2*py3-3*dx*px1*px3*py2*py3+6*ax*dx*px1*Power(py3,2)-18*dx*Power(px1,2)*Power(py3,2)-6*ax*dx*px2*Power(py3,2)+9*dx*px1*px2*Power(py3,2)+2*ax*dx*px3*Power(py3,2)-2*bx*(tmp1)*tmp2*(cy*(tmp1)-cx*tmp2)+2*ay*Power(tmp1,2)*(dy*(tmp1)-dx*tmp2))-ay*(tmp1)*(Power(cy,2)*Power(tmp1,2)-2*cx*cy*(tmp1)*tmp2+tmp2*(-2*bx*dy*(tmp1)+Power(cx,2)*tmp2+2*bx*dx*tmp2)));T c5=-3*(27*bx*Power(cy,2)*Power(px1,2)*py1+54*ax*cy*dy*Power(px1,2)*py1-54*bx*Power(cy,2)*px1*px2*py1-108*ax*cy*dy*px1*px2*py1+27*bx*Power(cy,2)*Power(px2,2)*py1+54*ax*cy*dy*Power(px2,2)*py1+54*cy*dy*px1*Power(px2,2)*py1+18*bx*Power(cy,2)*px1*px3*py1+36*ax*cy*dy*px1*px3*py1-36*cy*dy*Power(px1,2)*px3*py1-18*bx*Power(cy,2)*px2*px3*py1-36*ax*cy*dy*px2*px3*py1-54*cy*dy*px1*px2*px3*py1+3*bx*Power(cy,2)*Power(px3,2)*py1+6*ax*cy*dy*Power(px3,2)*py1+36*cy*dy*px1*Power(px3,2)*py1-6*cy*dy*px2*Power(px3,2)*py1-54*bx*cx*cy*px1*Power(py1,2)-54*ax*cy*dx*px1*Power(py1,2)-27*Power(bx,2)*dy*px1*Power(py1,2)-54*ax*cx*dy*px1*Power(py1,2)+54*bx*cx*cy*px2*Power(py1,2)+54*ax*cy*dx*px2*Power(py1,2)+27*Power(bx,2)*dy*px2*Power(py1,2)+54*ax*cx*dy*px2*Power(py1,2)-27*cy*dx*Power(px2,2)*Power(py1,2)-27*cx*dy*Power(px2,2)*Power(py1,2)-18*bx*cx*cy*px3*Power(py1,2)-18*ax*cy*dx*px3*Power(py1,2)-9*Power(bx,2)*dy*px3*Power(py1,2)-18*ax*cx*dy*px3*Power(py1,2)+36*cy*dx*px1*px3*Power(py1,2)+36*cx*dy*px1*px3*Power(py1,2)+27*cy*dx*px2*px3*Power(py1,2)+27*cx*dy*px2*px3*Power(py1,2)-18*cy*dx*Power(px3,2)*Power(py1,2)-18*cx*dy*Power(px3,2)*Power(py1,2)+27*bx*Power(cx,2)*Power(py1,3)+27*Power(bx,2)*dx*Power(py1,3)+54*ax*cx*dx*Power(py1,3)-36*cx*dx*px3*Power(py1,3)-27*bx*Power(cy,2)*Power(px1,2)*py2-54*ax*cy*dy*Power(px1,2)*py2+54*bx*Power(cy,2)*px1*px2*py2+108*ax*cy*dy*px1*px2*py2-54*cy*dy*Power(px1,2)*px2*py2-27*bx*Power(cy,2)*Power(px2,2)*py2-54*ax*cy*dy*Power(px2,2)*py2-18*bx*Power(cy,2)*px1*px3*py2-36*ax*cy*dy*px1*px3*py2+108*cy*dy*Power(px1,2)*px3*py2+18*bx*Power(cy,2)*px2*px3*py2+36*ax*cy*dy*px2*px3*py2-54*cy*dy*px1*px2*px3*py2+18*cy*dy*Power(px2,2)*px3*py2-3*bx*Power(cy,2)*Power(px3,2)*py2-6*ax*cy*dy*Power(px3,2)*py2-12*cy*dy*px1*Power(px3,2)*py2+108*bx*cx*cy*px1*py1*py2+108*ax*cy*dx*px1*py1*py2+54*Power(bx,2)*dy*px1*py1*py2+108*ax*cx*dy*px1*py1*py2-108*bx*cx*cy*px2*py1*py2-108*ax*cy*dx*px2*py1*py2-54*Power(bx,2)*dy*px2*py1*py2-108*ax*cx*dy*px2*py1*py2+36*bx*cx*cy*px3*py1*py2+36*ax*cy*dx*px3*py1*py2+18*Power(bx,2)*dy*px3*py1*py2+36*ax*cx*dy*px3*py1*py2-81*cy*dx*px1*px3*py1*py2-81*cx*dy*px1*px3*py1*py2+27*cy*dx*px2*px3*py1*py2+27*cx*dy*px2*px3*py1*py2+9*cy*dx*Power(px3,2)*py1*py2+9*cx*dy*Power(px3,2)*py1*py2-81*bx*Power(cx,2)*Power(py1,2)*py2-81*Power(bx,2)*dx*Power(py1,2)*py2-162*ax*cx*dx*Power(py1,2)*py2+54*cx*dx*px2*Power(py1,2)*py2+54*cx*dx*px3*Power(py1,2)*py2-54*bx*cx*cy*px1*Power(py2,2)-54*ax*cy*dx*px1*Power(py2,2)-27*Power(bx,2)*dy*px1*Power(py2,2)-54*ax*cx*dy*px1*Power(py2,2)+27*cy*dx*Power(px1,2)*Power(py2,2)+27*cx*dy*Power(px1,2)*Power(py2,2)+54*bx*cx*cy*px2*Power(py2,2)+54*ax*cy*dx*px2*Power(py2,2)+27*Power(bx,2)*dy*px2*Power(py2,2)+54*ax*cx*dy*px2*Power(py2,2)-18*bx*cx*cy*px3*Power(py2,2)-18*ax*cy*dx*px3*Power(py2,2)-9*Power(bx,2)*dy*px3*Power(py2,2)-18*ax*cx*dy*px3*Power(py2,2)+27*cy*dx*px1*px3*Power(py2,2)+27*cx*dy*px1*px3*Power(py2,2)-18*cy*dx*px2*px3*Power(py2,2)-18*cx*dy*px2*px3*Power(py2,2)+81*bx*Power(cx,2)*py1*Power(py2,2)+81*Power(bx,2)*dx*py1*Power(py2,2)+162*ax*cx*dx*py1*Power(py2,2)-54*cx*dx*px1*py1*Power(py2,2)-54*cx*dx*px3*py1*Power(py2,2)-27*bx*Power(cx,2)*Power(py2,3)-27*Power(bx,2)*dx*Power(py2,3)-54*ax*cx*dx*Power(py2,3)+18*cx*dx*px3*Power(py2,3)+9*bx*Power(cy,2)*Power(px1,2)*py3+18*ax*cy*dy*Power(px1,2)*py3+36*cy*dy*Power(px1,3)*py3-18*bx*Power(cy,2)*px1*px2*py3-36*ax*cy*dy*px1*px2*py3-54*cy*dy*Power(px1,2)*px2*py3+9*bx*Power(cy,2)*Power(px2,2)*py3+18*ax*cy*dy*Power(px2,2)*py3+54*cy*dy*px1*Power(px2,2)*py3-18*cy*dy*Power(px2,3)*py3+6*bx*Power(cy,2)*px1*px3*py3+12*ax*cy*dy*px1*px3*py3-36*cy*dy*Power(px1,2)*px3*py3-6*bx*Power(cy,2)*px2*px3*py3-12*ax*cy*dy*px2*px3*py3+18*cy*dy*px1*px2*px3*py3+bx*Power(cy,2)*Power(px3,2)*py3+2*ax*cy*dy*Power(px3,2)*py3-36*bx*cx*cy*px1*py1*py3-36*ax*cy*dx*px1*py1*py3-18*Power(bx,2)*dy*px1*py1*py3-36*ax*cx*dy*px1*py1*py3-36*cy*dx*Power(px1,2)*py1*py3-36*cx*dy*Power(px1,2)*py1*py3+36*bx*cx*cy*px2*py1*py3+36*ax*cy*dx*px2*py1*py3+18*Power(bx,2)*dy*px2*py1*py3+36*ax*cx*dy*px2*py1*py3+81*cy*dx*px1*px2*py1*py3+81*cx*dy*px1*px2*py1*py3-27*cy*dx*Power(px2,2)*py1*py3-27*cx*dy*Power(px2,2)*py1*py3-12*bx*cx*cy*px3*py1*py3-12*ax*cy*dx*px3*py1*py3-6*Power(bx,2)*dy*px3*py1*py3-12*ax*cx*dy*px3*py1*py3-3*cy*dx*px2*px3*py1*py3-3*cx*dy*px2*px3*py1*py3+27*bx*Power(cx,2)*Power(py1,2)*py3+27*Power(bx,2)*dx*Power(py1,2)*py3+54*ax*cx*dx*Power(py1,2)*py3+36*cx*dx*px1*Power(py1,2)*py3-108*cx*dx*px2*Power(py1,2)*py3+36*cx*dx*px3*Power(py1,2)*py3+36*bx*cx*cy*px1*py2*py3+36*ax*cy*dx*px1*py2*py3+18*Power(bx,2)*dy*px1*py2*py3+36*ax*cx*dy*px1*py2*py3-27*cy*dx*Power(px1,2)*py2*py3-27*cx*dy*Power(px1,2)*py2*py3-36*bx*cx*cy*px2*py2*py3-36*ax*cy*dx*px2*py2*py3-18*Power(bx,2)*dy*px2*py2*py3-36*ax*cx*dy*px2*py2*py3-27*cy*dx*px1*px2*py2*py3-27*cx*dy*px1*px2*py2*py3+18*cy*dx*Power(px2,2)*py2*py3+18*cx*dy*Power(px2,2)*py2*py3+12*bx*cx*cy*px3*py2*py3+12*ax*cy*dx*px3*py2*py3+6*Power(bx,2)*dy*px3*py2*py3+12*ax*cx*dy*px3*py2*py3+3*cy*dx*px1*px3*py2*py3+3*cx*dy*px1*px3*py2*py3-54*bx*Power(cx,2)*py1*py2*py3-54*Power(bx,2)*dx*py1*py2*py3-108*ax*cx*dx*py1*py2*py3+54*cx*dx*px1*py1*py2*py3+54*cx*dx*px2*py1*py2*py3-18*cx*dx*px3*py1*py2*py3+27*bx*Power(cx,2)*Power(py2,2)*py3+27*Power(bx,2)*dx*Power(py2,2)*py3+54*ax*cx*dx*Power(py2,2)*py3-18*cx*dx*px2*Power(py2,2)*py3-6*bx*cx*cy*px1*Power(py3,2)-6*ax*cy*dx*px1*Power(py3,2)-3*Power(bx,2)*dy*px1*Power(py3,2)-6*ax*cx*dy*px1*Power(py3,2)+18*cy*dx*Power(px1,2)*Power(py3,2)+18*cx*dy*Power(px1,2)*Power(py3,2)+6*bx*cx*cy*px2*Power(py3,2)+6*ax*cy*dx*px2*Power(py3,2)+3*Power(bx,2)*dy*px2*Power(py3,2)+6*ax*cx*dy*px2*Power(py3,2)-9*cy*dx*px1*px2*Power(py3,2)-9*cx*dy*px1*px2*Power(py3,2)-2*bx*cx*cy*px3*Power(py3,2)-2*ax*cy*dx*px3*Power(py3,2)-Power(bx,2)*dy*px3*Power(py3,2)-2*ax*cx*dy*px3*Power(py3,2)+9*bx*Power(cx,2)*py1*Power(py3,2)+9*Power(bx,2)*dx*py1*Power(py3,2)+18*ax*cx*dx*py1*Power(py3,2)-36*cx*dx*px1*py1*Power(py3,2)+12*cx*dx*px2*py1*Power(py3,2)-9*bx*Power(cx,2)*py2*Power(py3,2)-9*Power(bx,2)*dx*py2*Power(py3,2)-18*ax*cx*dx*py2*Power(py3,2)+6*cx*dx*px1*py2*Power(py3,2)+bx*Power(cx,2)*Power(py3,3)+Power(bx,2)*dx*Power(py3,3)+2*ax*cx*dx*Power(py3,3)-2*ay*(tmp1)*(cy*(tmp1)-cx*tmp2)*(dy*(tmp1)-dx*tmp2)+Power(by,2)*Power(tmp1,2)*(-(dy*(tmp1))+dx*tmp2)-by*(tmp1)*(Power(cy,2)*Power(tmp1,2)-2*cx*cy*(tmp1)*tmp2+tmp2*(-2*bx*dy*(tmp1)+Power(cx,2)*tmp2+2*bx*dx*tmp2)));T c6=+(Power(cy,3)*Power(tmp1,3)-162*by*cx*dy*Power(px1,2)*py1-81*ax*Power(dy,2)*Power(px1,2)*py1+324*by*cx*dy*px1*px2*py1+162*ax*Power(dy,2)*px1*px2*py1-162*by*cx*dy*Power(px2,2)*py1-81*ax*Power(dy,2)*Power(px2,2)*py1-81*Power(dy,2)*px1*Power(px2,2)*py1-108*by*cx*dy*px1*px3*py1-54*ax*Power(dy,2)*px1*px3*py1+54*Power(dy,2)*Power(px1,2)*px3*py1+108*by*cx*dy*px2*px3*py1+54*ax*Power(dy,2)*px2*px3*py1+81*Power(dy,2)*px1*px2*px3*py1-18*by*cx*dy*Power(px3,2)*py1-9*ax*Power(dy,2)*Power(px3,2)*py1-54*Power(dy,2)*px1*Power(px3,2)*py1+9*Power(dy,2)*px2*Power(px3,2)*py1+162*by*cx*dx*px1*Power(py1,2)+162*bx*cx*dy*px1*Power(py1,2)+162*ax*dx*dy*px1*Power(py1,2)-162*by*cx*dx*px2*Power(py1,2)-162*bx*cx*dy*px2*Power(py1,2)-162*ax*dx*dy*px2*Power(py1,2)+81*dx*dy*Power(px2,2)*Power(py1,2)+54*by*cx*dx*px3*Power(py1,2)+54*bx*cx*dy*px3*Power(py1,2)+54*ax*dx*dy*px3*Power(py1,2)-108*dx*dy*px1*px3*Power(py1,2)-81*dx*dy*px2*px3*Power(py1,2)+54*dx*dy*Power(px3,2)*Power(py1,2)-27*Power(cx,3)*Power(py1,3)-162*bx*cx*dx*Power(py1,3)-81*ax*Power(dx,2)*Power(py1,3)+54*Power(dx,2)*px3*Power(py1,3)+162*by*cx*dy*Power(px1,2)*py2+81*ax*Power(dy,2)*Power(px1,2)*py2-324*by*cx*dy*px1*px2*py2-162*ax*Power(dy,2)*px1*px2*py2+81*Power(dy,2)*Power(px1,2)*px2*py2+162*by*cx*dy*Power(px2,2)*py2+81*ax*Power(dy,2)*Power(px2,2)*py2+108*by*cx*dy*px1*px3*py2+54*ax*Power(dy,2)*px1*px3*py2-162*Power(dy,2)*Power(px1,2)*px3*py2-108*by*cx*dy*px2*px3*py2-54*ax*Power(dy,2)*px2*px3*py2+81*Power(dy,2)*px1*px2*px3*py2-27*Power(dy,2)*Power(px2,2)*px3*py2+18*by*cx*dy*Power(px3,2)*py2+9*ax*Power(dy,2)*Power(px3,2)*py2+18*Power(dy,2)*px1*Power(px3,2)*py2-324*by*cx*dx*px1*py1*py2-324*bx*cx*dy*px1*py1*py2-324*ax*dx*dy*px1*py1*py2+324*by*cx*dx*px2*py1*py2+324*bx*cx*dy*px2*py1*py2+324*ax*dx*dy*px2*py1*py2-108*by*cx*dx*px3*py1*py2-108*bx*cx*dy*px3*py1*py2-108*ax*dx*dy*px3*py1*py2+243*dx*dy*px1*px3*py1*py2-81*dx*dy*px2*px3*py1*py2-27*dx*dy*Power(px3,2)*py1*py2+81*Power(cx,3)*Power(py1,2)*py2+486*bx*cx*dx*Power(py1,2)*py2+243*ax*Power(dx,2)*Power(py1,2)*py2-81*Power(dx,2)*px2*Power(py1,2)*py2-81*Power(dx,2)*px3*Power(py1,2)*py2+162*by*cx*dx*px1*Power(py2,2)+162*bx*cx*dy*px1*Power(py2,2)+162*ax*dx*dy*px1*Power(py2,2)-81*dx*dy*Power(px1,2)*Power(py2,2)-162*by*cx*dx*px2*Power(py2,2)-162*bx*cx*dy*px2*Power(py2,2)-162*ax*dx*dy*px2*Power(py2,2)+54*by*cx*dx*px3*Power(py2,2)+54*bx*cx*dy*px3*Power(py2,2)+54*ax*dx*dy*px3*Power(py2,2)-81*dx*dy*px1*px3*Power(py2,2)+54*dx*dy*px2*px3*Power(py2,2)-81*Power(cx,3)*py1*Power(py2,2)-486*bx*cx*dx*py1*Power(py2,2)-243*ax*Power(dx,2)*py1*Power(py2,2)+81*Power(dx,2)*px1*py1*Power(py2,2)+81*Power(dx,2)*px3*py1*Power(py2,2)+27*Power(cx,3)*Power(py2,3)+162*bx*cx*dx*Power(py2,3)+81*ax*Power(dx,2)*Power(py2,3)-27*Power(dx,2)*px3*Power(py2,3)-54*by*cx*dy*Power(px1,2)*py3-27*ax*Power(dy,2)*Power(px1,2)*py3-54*Power(dy,2)*Power(px1,3)*py3+108*by*cx*dy*px1*px2*py3+54*ax*Power(dy,2)*px1*px2*py3+81*Power(dy,2)*Power(px1,2)*px2*py3-54*by*cx*dy*Power(px2,2)*py3-27*ax*Power(dy,2)*Power(px2,2)*py3-81*Power(dy,2)*px1*Power(px2,2)*py3+27*Power(dy,2)*Power(px2,3)*py3-36*by*cx*dy*px1*px3*py3-18*ax*Power(dy,2)*px1*px3*py3+54*Power(dy,2)*Power(px1,2)*px3*py3+36*by*cx*dy*px2*px3*py3+18*ax*Power(dy,2)*px2*px3*py3-27*Power(dy,2)*px1*px2*px3*py3-6*by*cx*dy*Power(px3,2)*py3-3*ax*Power(dy,2)*Power(px3,2)*py3+108*by*cx*dx*px1*py1*py3+108*bx*cx*dy*px1*py1*py3+108*ax*dx*dy*px1*py1*py3+108*dx*dy*Power(px1,2)*py1*py3-108*by*cx*dx*px2*py1*py3-108*bx*cx*dy*px2*py1*py3-108*ax*dx*dy*px2*py1*py3-243*dx*dy*px1*px2*py1*py3+81*dx*dy*Power(px2,2)*py1*py3+36*by*cx*dx*px3*py1*py3+36*bx*cx*dy*px3*py1*py3+36*ax*dx*dy*px3*py1*py3+9*dx*dy*px2*px3*py1*py3-27*Power(cx,3)*Power(py1,2)*py3-162*bx*cx*dx*Power(py1,2)*py3-81*ax*Power(dx,2)*Power(py1,2)*py3-54*Power(dx,2)*px1*Power(py1,2)*py3+162*Power(dx,2)*px2*Power(py1,2)*py3-54*Power(dx,2)*px3*Power(py1,2)*py3-108*by*cx*dx*px1*py2*py3-108*bx*cx*dy*px1*py2*py3-108*ax*dx*dy*px1*py2*py3+81*dx*dy*Power(px1,2)*py2*py3+108*by*cx*dx*px2*py2*py3+108*bx*cx*dy*px2*py2*py3+108*ax*dx*dy*px2*py2*py3+81*dx*dy*px1*px2*py2*py3-54*dx*dy*Power(px2,2)*py2*py3-36*by*cx*dx*px3*py2*py3-36*bx*cx*dy*px3*py2*py3-36*ax*dx*dy*px3*py2*py3-9*dx*dy*px1*px3*py2*py3+54*Power(cx,3)*py1*py2*py3+324*bx*cx*dx*py1*py2*py3+162*ax*Power(dx,2)*py1*py2*py3-81*Power(dx,2)*px1*py1*py2*py3-81*Power(dx,2)*px2*py1*py2*py3+27*Power(dx,2)*px3*py1*py2*py3-27*Power(cx,3)*Power(py2,2)*py3-162*bx*cx*dx*Power(py2,2)*py3-81*ax*Power(dx,2)*Power(py2,2)*py3+27*Power(dx,2)*px2*Power(py2,2)*py3+18*by*cx*dx*px1*Power(py3,2)+18*bx*cx*dy*px1*Power(py3,2)+18*ax*dx*dy*px1*Power(py3,2)-54*dx*dy*Power(px1,2)*Power(py3,2)-18*by*cx*dx*px2*Power(py3,2)-18*bx*cx*dy*px2*Power(py3,2)-18*ax*dx*dy*px2*Power(py3,2)+27*dx*dy*px1*px2*Power(py3,2)+6*by*cx*dx*px3*Power(py3,2)+6*bx*cx*dy*px3*Power(py3,2)+6*ax*dx*dy*px3*Power(py3,2)-9*Power(cx,3)*py1*Power(py3,2)-54*bx*cx*dx*py1*Power(py3,2)-27*ax*Power(dx,2)*py1*Power(py3,2)+54*Power(dx,2)*px1*py1*Power(py3,2)-18*Power(dx,2)*px2*py1*Power(py3,2)+9*Power(cx,3)*py2*Power(py3,2)+54*bx*cx*dx*py2*Power(py3,2)+27*ax*Power(dx,2)*py2*Power(py3,2)-9*Power(dx,2)*px1*py2*Power(py3,2)-Power(cx,3)*Power(py3,3)-6*bx*cx*dx*Power(py3,3)-3*ax*Power(dx,2)*Power(py3,3)-3*cx*Power(cy,2)*Power(tmp1,2)*tmp2+3*ay*(tmp1)*Power(dy*(tmp1)-dx*tmp2,2)+3*cy*(tmp1)*(2*by*(tmp1)*(dy*(tmp1)-dx*tmp2)+tmp2*(-2*bx*dy*(tmp1)+Power(cx,2)*tmp2+2*bx*dx*tmp2)));T c7=+3*(dy*(tmp1)-dx*tmp2)*(Power(cy,2)*Power(tmp1,2)-2*cx*cy*(tmp1)*tmp2+by*(tmp1)*(dy*(tmp1)-dx*tmp2)+tmp2*(-(bx*dy*(tmp1))+Power(cx,2)*tmp2+bx*dx*tmp2));T c8=+3*(cy*(tmp1)-cx*tmp2)*Power(dy*(tmp1)-dx*tmp2,2);T tmp=dy*(tmp1)-dx*tmp2;T c9=tmp*tmp*tmp;return{c0,c1,c2,c3,c4,c5,c6,c7,c8,c9};

            // clang-format on
        }

        template<typename T>
        void generate_coefficients(const CubicBezier &bezier, const CubicBezier &q, std::array<T, 10> &out) {
            T dx = q.p0.x();
            T dy = q.p0.y();
            T b0x = bezier.p0.x(), b1x = bezier.p1.x(), b2x = bezier.p2.x(), b3x = bezier.p3.x();
            T b0y = bezier.p0.y(), b1y = bezier.p1.y(), b2y = bezier.p2.y(), b3y = bezier.p3.y();
            T px1 = q.p1.x();
            T py1 = q.p1.y();
            T px2 = q.p2.x();
            T py2 = q.p2.y();
            T px3 = q.p3.x();
            T py3 = q.p3.y();

            b0x -= dx;
            b0y -= dy;
            b1x -= dx;
            b1y -= dy;
            b2x -= dx;
            b2y -= dy;
            b3x -= dx;
            b3y -= dy;

            px1 -= dx;
            py1 -= dy;
            px2 -= dx;
            py2 -= dy;
            px3 -= dx;
            py3 -= dy;

            out = generate_coefficients<T>(
                    b0x, b0y, b1x, b1y, b2x, b2y, b3x, b3y,
                    px1, py1, px2, py2, px3, py3
            );
            T absmax = out.front();
            using std::abs;
            for (std::size_t i = 1; i < out.size(); ++i) {
                if (abs(out[i]) > absmax) {
                    absmax = abs(out[i]);
                }
            }
            if (absmax > 1) {
                for (std::size_t i = 0; i < out.size(); ++i) {
                    out[i] /= absmax;
                }
            }
        }

        template<typename IntersectionConsumer, class numeric_t = double, typename CollinearFunc = IsCollinear>
        void get_intersection_detail(const CubicBezier &bezier, const CubicBezier &q,
                                     IntersectionConsumer &report,
                                     const numeric_t &abstol, const double interval_eps = 1e-14,
                                     const int maxiter = 25) {
            // q is the curve that is transformed in implicit form, bezier is the curve on which t values are found
            std::array<numeric_t, 10> poly;
            generate_coefficients(bezier, q, poly);

            std::array<double, 10> poly_d{double(poly[0]), double(poly[1]), double(poly[2]), double(poly[3]),
                                          double(poly[4]),
                                          double(poly[5]), double(poly[6]), double(poly[7]), double(poly[8]),
                                          double(poly[9])};
            polynomialsolver::PolynomialFunc<10, double> polyfunc_d(poly_d);
            polynomialsolver::PolynomialFunc<10, numeric_t> polyfunc(poly);

            auto inv = curveinverter<CollinearFunc>(q);

            auto handle_root = [&](const double t) {
                Point2d p = beziermap(bezier, t);
                double u = inv(p.x(), p.y());
                if (unit_inter(u)) {
                    report(t, u, p);
                }
            };

            double prev_root = -1.;
            using std::abs;
            auto add = [&](const std::pair<numeric_t, numeric_t> &interval) {
                if (interval.first == numeric_t(0)) {
                    if (abs(polyfunc(numeric_t(0))) <= abstol) {
                        if (prev_root != 0.) {
                            prev_root = 0.;
                            if (!(bezier.p0 == q.p0 || bezier.p0 == q.p3)) {
                                handle_root(0.);
                            }
                        }
                        return;
                    }
                }

                if (interval.second == numeric_t(1)) {
                    if (abs(polyfunc(numeric_t(1))) <= abstol) {
                        if (prev_root != 1.) {
                            prev_root = 1.;
                            if (!(bezier.p3 == q.p3 || bezier.p3 == q.p0)) {
                                handle_root(1.);
                            }
                        }
                        return;
                    }
                }

                auto maybe_root = polynomialsolver::itp_root_refine(polyfunc_d,
                                                                    double(interval.first), double(interval.second),
                                                                    interval_eps, maxiter);
                if (maybe_root) {
                    auto t = (double) *maybe_root;
                    if (prev_root != t) {
                        prev_root = t;
                        handle_root(t);
                    }
                }
            };
            polynomialsolver::rootbracket(poly, add, numeric_t(abstol));
        }

        // Intersects the curves b1 and b2. Intersections are passed to the IntersectionConsumer callback,
        // more precisely the parameters t, u, p are passed, where t is the parametric value of the first curve,
        // u the parametric value of the second curve, and p is the intersection point_.
        // preconditions: - curve must not be equivalent to a line -curve cannot intersect itself in another point_ than
        // the start-end points.
        template<typename IntersectionConsumer, class numeric_t = double, typename CollinearFunc = IsCollinear>
        void curve_curve_inter(const CubicBezier &b1, const CubicBezier &b2, IntersectionConsumer &report,
                               const numeric_t &abstol = (numeric_t) 1e-10) {
            if (b1 == b2) {
                return;
            }
            BBox box1{}, box2{};
            make_hull_bbox(b1, box1);
            make_hull_bbox(b2,box2);
            bool nointersect = !box1.strict_overlap(box2);
            if (nointersect) {
                return;
            }

            bool switch_order = !bezier_ordering(b1, b2);
            auto report_impl = [&](const double t, const double u, const Point2d &p) {
                if (switch_order) {
                    return report(u, t, p);
                } else {
                    return report(t, u, p);
                }
            };

            CubicBezier b1_ = b1, b2_ = b2;
            if (switch_order) std::swap(b1_, b2_);
            get_intersection_detail<decltype(report_impl), double, CollinearFunc>(b1_, b2_, report_impl, abstol);
        }
    }
#endif //CONTOURKLIP_BEZIER_UTILS_HPP
#ifndef CONTOURKLIP_SWEEPPOINT_HPP
#define CONTOURKLIP_SWEEPPOINT_HPP


namespace contourklip {
    enum BooleanOpType {
        UNION = 0,
        INTERSECTION = 1,
        DIFFERENCE = 2,
        XOR = 3,
        DIVIDE = 4
    };

    std::ostream &operator<<(std::ostream &o, const BooleanOpType &p) {
        switch (p) {
            case INTERSECTION:
                return o << "intersection";
            case UNION:
                return o << "union";
            case DIFFERENCE:
                return o << "difference";
            case XOR:
                return o << "xor";
            case DIVIDE:
                return o << "divide";
        }
        return o;
    }

    namespace detail {
        enum EdgeType {
            NORMAL, SAME_TRANSITION, DIFFERENT_TRANSITION
        };
        enum PolygonType {
            SUBJECT = 0,
            CLIPPING = 1
        };

        struct SweepPoint {
            SweepPoint() = default;

            bool left = false;
            Point2d point;
            SweepPoint *other_point = nullptr;
            PolygonType ptype{};
            std::size_t contourid = 0;

            //index at which SL iterator to other sp is stored
            std::size_t other_iter_pos = 0;
            bool in_out = false; // if for a ray passing upwards into the edge, it is an inside-outside transition
            bool other_in_out = false; // inout for the closest edge downward in SL that is from the other polygon

            // indicates if the edge associated to this point is in the result contour of the clipping
            // operation given by the index. 0 = default, 1 = INTERSECTION, 2 = DIFFERENCE
            std::array<bool, 3> in_result{};
            // follows the same principle, but instead maps to the previous SweepPoint* (downwards)
            // which is in the result.
            std::array<SweepPoint *, 3> prev_in_result{};

            //the following fields are used when connecting the edges
            std::size_t pos = 0; // position in the result array
            bool result_in_out = false; //if the associated edge is an in out transition into its result contour
            std::size_t result_contour_id = 0;
            EdgeType edgetype = NORMAL;

            //used if segment is curve
            bool curve = false;
            bool islast = false;
            Point2d controlp;
            Point2d initial_controlp;
            SweepPoint *start = nullptr;

            SweepPoint(bool left, const Point2d &point,
                       SweepPoint *otherPoint) :
                    left(left), point(point), other_point(otherPoint) {}

            explicit SweepPoint(const Point2d &point) :
                    point(point) {}

            bool vertical() const { return point.x() == other_point->point.x(); }

            void set_if_left() {
                left = increasing(point, other_point->point);
                this->other_point->left = !left;
            }
        };

        std::ostream &operator<<(std::ostream &o, const SweepPoint &p) {
            if (p.other_point) {
                o << "[" << p.point << "->" << p.other_point->point;
                if (p.left && p.curve) o << "\n--->c" << p.controlp << "->" << p.other_point->controlp;
                o << ", l " << p.left
                  << ", res " << p.in_result[0]
                  << ", ptype " << p.ptype
                  << ", cid " << p.result_contour_id
                  << ", c " << p.curve
                  << "]";
                return o;
            } else {
                return o << "[" << p.point << "->" << " [nullptr] " << p.left << "]";
            }
        }

        bool overlapping(const SweepPoint *e1, const SweepPoint *e2) {
            if (e1->curve != e2->curve) {
                return false;
            }
            bool overlapping_ends = e1->point == e2->point
                                    && e1->other_point->point == e2->other_point->point;
            if (!e1->curve) {
                return overlapping_ends;
            }

            return overlapping_ends
                   && e1->controlp == e2->controlp
                   && e1->other_point->controlp == e2->other_point->controlp;
        }

        //Returns true iff the segment associated with e1 is below a point p.
        auto curve_below_point = [](const SweepPoint *e1, const Point2d &p) -> bool {

            CubicBezier c{e1->point, e1->controlp,
                          e1->other_point->controlp, e1->other_point->point};

            double a = 0., b = 1.;
            Point2d left = c.p0;
            Point2d right = c.p3;
            Point2d sample;
            while ((b - a) > 1e-10) {
                if (left.y() < p.y() && right.y() < p.y()) {
                    return true;
                }
                if (left.y() >= p.y() && right.y() >= p.y()) {
                    return false;
                }
                double mid = 0.5 * (a + b);
                sample = beziermap(c, mid);
                if (sample.x() < p.x()) {
                    a = mid;
                    left = sample;
                } else {
                    b = mid;
                    right = sample;
                }
            }
            return sample.y() < p.y();
        };


        // check if the associated bezier curve of the first is below the associated bezier curve of the second.
        // preconditions: both are curves, share the endpoint (may be start or end), and otherwise do not intersect.
        template<typename Orient2DF = LeftOfLine, typename CollinearF = IsCollinear>
        bool curve_below(const SweepPoint *e1, const SweepPoint *e2, CollinearF f = {}) {
            if (!f(e1->point, e1->controlp, e2->controlp)
                && e1->point != e1->controlp) { // special case with vanishing derivative
                if (vertical(e1->point, e1->controlp)) {
                    return e1->controlp.y() < e1->point.y();
                }
                return above_line<Orient2DF>(e1->point, e1->controlp, e2->controlp);
            }
            const SweepPoint *sp = e1;
            const SweepPoint *other = e2;
            bool reversed;
            // we want to sample the point on the curve which is shortest in the x direction
            if ((reversed = e1->left == (e1->other_point->point.x()
                                         > e2->other_point->point.x()))) {
                std::swap(sp, other);
            }
            Point2d a = beziermap(sp->point, sp->controlp,
                                  sp->other_point->controlp, sp->other_point->point, 0.5);

            CubicBezier tmp{other->point, other->controlp,
                            other->other_point->controlp, other->other_point->point};
            double t = t_from_x(tmp, a.x());

            double y_other = beziermap(tmp, t).y();
            return reversed ? a.y() > y_other : a.y() < y_other;
        }

        // This is the comparator used for the sweeppoint queue. returns true iff e1 < e2.
        template<typename Orient2DF = LeftOfLine, typename CollinearF = IsCollinear>
        bool queue_comp(const SweepPoint *e1, const SweepPoint *e2) {
            CollinearF collinear{};
            if (e1->point.x() != e2->point.x())
                return e1->point.x() < e2->point.x();
            if (e1->point.y() !=
                e2->point.y())
                return e1->point.y() < e2->point.y();

            if (e1->left != e2->left) {
                //right endpoint is processed first.
                return e2->left;
            }

            if (overlapping(e1, e2)) {
                return e1->ptype < e2->ptype;
            }
            // Both events represent lines
            if (!e1->curve && !e2->curve) {
                if (!collinear(e1->point, e1->other_point->point, e2->other_point->point)) {
                    // the event associate to the bottom segment is processed first
                    return above_line<Orient2DF>(e1->point, e1->other_point->point, e2->other_point->point);
                }
                return e1->ptype < e2->ptype;
            }

            // very special case where curve_below fails to differentiate due to round-off.
            // In that case we use some consistent criterion.
            // At this point the segments do not exactly overlap.
            bool a = curve_below<Orient2DF, CollinearF>(e1, e2);
            bool b = curve_below<Orient2DF, CollinearF>(e2, e1);
            if (a == b) {
                if (e1->ptype != e2->ptype) return e1->ptype < e2->ptype;
                if (e1->other_point->point != e2->other_point->point)
                    return increasing(e1->other_point->point, e2->other_point->point);
                if (e1->controlp != e2->controlp) return increasing(e1->controlp, e2->controlp);
                return increasing(e1->other_point->controlp, e2->other_point->controlp);
            }
            //at least one point is from a curve
            return a;
        }

        // Comparator used for the sweep line. returns true iff le1 < le2.
        // Note that only left events can be in the sweep line.
        template<typename Orient2DF, typename CollinearF>
        struct SComp {
            bool operator()(const SweepPoint *le1, const SweepPoint *le2) const {
                if (le1 == le2)
                    return false;

                if (overlapping(le1, le2)) {
                    return le1->ptype < le2->ptype;
                }

                if (le1->point == le2->point) {
                    return queue_comp<Orient2DF, CollinearF>(le1, le2);
                }

                if (le1->point.x() == le2->point.x()) {
                    return le1->point.y() < le2->point.y();
                }

                if (!le1->curve && !le2->curve) {
                    if (queue_comp<Orient2DF, CollinearF>(le1, le2)) {
                        return above_line<Orient2DF>(le1->point,
                                                     le1->other_point->point, le2->point);
                    }
                    return above_line<Orient2DF>(le2->point,
                                                 le1->point, le2->other_point->point);
                }

                //one of the segments is a curve.
                if (queue_comp<Orient2DF, CollinearF>(le1, le2)) {
                    // le1 has been inserted first.
                    return curve_below_point(le1, le2->point);
                }
                return !curve_below_point(le2, le1->point);
            }
        };
    }
}
#endif //CONTOURKLIP_SWEEPPOINT_HPP
#ifndef CONTOURKLIP_CONTOUR_POSTPROCESSING_HPP
#define CONTOURKLIP_CONTOUR_POSTPROCESSING_HPP


namespace contourklip::detail {
        template<typename outF, typename CollinearF = IsCollinear>
        void postprocess_contour(Contour &c, outF &report_contour, bool remove_collinear = true,
                                 CollinearF collinear_f = {}) {
            if (c.size() <= 3) {
                report_contour(c);
                return;
            }

            std::map<Point2d, std::size_t> visited_p{};
            std::vector<std::size_t> skip(c.size(), 0);
            std::fill(skip.begin(), skip.end(), 0);

            std::size_t prev;
            for (std::size_t i = 0; i < c.size(); ++i) {
                auto v = visited_p.find(c[i].point());
                if (v != visited_p.end()) {
                    prev = v->second;
                    // update the value to be the last updated
                    v->second = i;
                    // it could also be that we have an overl. point of a sub-contour that is already deleted.
                    if (skip[prev] != 0) {
                        continue;
                    }

                    Contour subcontour{};
                    //we still need to keep one of the 2 points on the contour
                    for (std::size_t j = prev; j < i; ++j) {
                        if (remove_collinear && subcontour.size() >= 2
                            && !subcontour.back().bcurve() && !c[j].bcurve()
                            && collinear_f(subcontour[subcontour.size() - 2].point(),
                                           subcontour.back_point(),
                                           c[j].point())
                                ) {
                            subcontour.back().point() = c[j].point();
                        } else {
                            subcontour.push_back(c[j]);
                        }
                        if (skip[j]) {
                            j = skip[j];
                        }
                        skip[j] = i;
                    }
                    subcontour.push_back(c[i]);
                    if (subcontour.size() <= 2) {
                        continue;
                    }
                    report_contour(subcontour);
                }
                    // current point is new
                else {
                    visited_p.insert({c[i].point(), i});
                }
            }
        }
    }
#endif //CONTOURKLIP_CONTOUR_POSTPROCESSING_HPP
#ifndef CONTOURKLIP_POLYCLIP_HPP
#define CONTOURKLIP_POLYCLIP_HPP


namespace contourklip {
    using namespace detail;

#define CONTOURKLIP_IF_NOT(stmt, msg) if( ! (stmt) )

    template<typename T = Segment>
    struct ContourSegment{
        T seg;
        std::size_t contourid;
        detail::PolygonType ptype;
    };

    struct SegIndent {
        detail::PolygonType ptype;
        bool curve;
        std::size_t idx;
        std::size_t contour_id;
    };

    bool operator==(const SegIndent &a, const SegIndent &b) {
        return a.idx == b.idx && a.curve == b.curve && a.ptype == b.ptype;
    }

    struct IntersectionValue {
        double t_val;
        Point2d p{};
        SegIndent id;
    };

    bool operator<(const IntersectionValue &a, const IntersectionValue &b) {
        if (a.id.ptype != b.id.ptype) {
            return a.id.ptype < b.id.ptype;
        }
        if (a.id.curve != b.id.curve) {
            return a.id.curve < b.id.curve;
        }
        if (a.id.idx != b.id.idx) {
            return a.id.idx < b.id.idx;
        }
        if(a.p == b.p) {
            return false;
        }
        return a.t_val < b.t_val;
    }

    std::ostream &operator<<(std::ostream &o, const IntersectionValue &v) {
        return o << "[t:" << v.t_val << ", " << v.p << ", "
                 << "ptype: " << v.id.ptype << ", c:" << v.id.curve << ", i:" << v.id.idx << "]";
    }

    struct Config{
        bool postprocess = true;
        bool postprocess_collinear = true;
        bool fail_on_approx_equal = true;
        double approx_equal_tol = 1e-6;
    };

    template<typename Orient2dFunc = LeftOfLine, typename CollinearFunc = IsCollinear>
    class PolyClip {
    private:
        using LineSegmentIt= std::vector<ContourSegment<Segment>>::const_iterator;
        using CurveSegmentIt = std::vector<ContourSegment<CubicBezier>>::const_iterator;
        enum BooleanOpTypeImpl {
            IMPL_UNION_ = 0,
            IMPL_INTERSECTION_ = 1,
            IMPL_DIFFERENCE_2_ = 2,
            IMPL_DIFFERENCE_ = 3,
            IMPL_XOR_ = 4
        };

        BooleanOpType initial_clippingop;
        LineSegmentIt a_begin, a_end;
        CurveSegmentIt b_begin, b_end;

        std::vector<Contour> &resultpoly;

        BooleanOpTypeImpl used_clippingop_;
        std::set<IntersectionValue> inters_;
        std::vector<ContourSegment<Segment>> lines_{};
        std::vector<ContourSegment<CubicBezier>> curves_{};

        std::deque<SweepPoint> resource_holder_{};
        std::vector<SweepPoint *> queue_{};
        detail::SComp<Orient2dFunc, CollinearFunc> sline_comp_{};
        std::set<SweepPoint *, decltype(sline_comp_)> sline_{sline_comp_};
        using sline_iterator_t = typename decltype(sline_)::iterator;
        std::vector<sline_iterator_t> other_iters_;

        bool bad_ = false;
        Config config_;
    public:
PolyClip(const std::vector<Contour> &a, const std::vector<Contour> &b,
                                       std::vector<Contour> &result, BooleanOpType clippingop, Config c = {}) :
                initial_clippingop(clippingop), resultpoly(result), config_(c) {
            collect_segments(a, b);
            init_op_enum();
        }

        /// \brief indicates if the clipping operation succeded. If it is false, the Multipolygon this.resultpoly
        /// which was supposed to store the result may contain anything.
        /// \return true if the clipping operation succeded, false otherwise.
        bool success() noexcept {
            return !this->bad_;
        }
        /// \brief computes the clipping operation of the stored input
        void compute() noexcept {
            //phase 1
            inters_ = std::set<IntersectionValue>{};
            if (!intersect_all_segments(lines_.begin(), lines_.end(),
                                    curves_.begin(), curves_.end(), config_, inters_)){
                this->bad_ = true;
                return;
            }


            std::size_t num_estimate = 2 * inters_.size() - 2 * lines_.size() + curves_.size();
            queue_.reserve(num_estimate);
            init_queue();
            std::sort(queue_.begin(), queue_.end(), detail::queue_comp<Orient2dFunc, CollinearFunc>);
            other_iters_ = std::vector<sline_iterator_t>(queue_.size());
            queue_correctness();
            if (!success()) {
                return;
            }

            //phase 2
            sweep();
            if (!success()) {
                return;
            }

            connect_edges(0);

            if (initial_clippingop == XOR){
                connect_edges(IMPL_DIFFERENCE_2_);
            }

            if (initial_clippingop == DIVIDE){
                connect_edges(IMPL_DIFFERENCE_2_);
                connect_edges(IMPL_INTERSECTION_);
            }
        }

    private:
        void collect_segments(const std::vector<Contour> &a, const std::vector<Contour> &b) {
            std::size_t contour_idx = 0;
            detail::PolygonType currpolygon = detail::SUBJECT;

            auto add_line_segment = [this, &contour_idx, &currpolygon](const Point2d& a, const Point2d b) {
                bool inc = increasing(a, b);
                if (inc) {
                    this->lines_.push_back({{a, b}, contour_idx, currpolygon});
                } else {
                    this->lines_.push_back({{b, a}, contour_idx, currpolygon});
                }
            };

            auto add_curve_segment = [this, &contour_idx, &currpolygon](const Point2d& p0,
                    const Point2d& p1, const Point2d& p2, const Point2d& p3) {
                bool inc = bezier_direction({p0, p1, p2, p3});
                if (inc) {
                    this->curves_.push_back({{p0, p1, p2, p3}, contour_idx, currpolygon});
                } else {
                    this->curves_.push_back({{p3, p2, p1, p0}, contour_idx, currpolygon});
                }
            };

            for (auto it = a.begin(); it != a.end(); ++it, ++contour_idx) {
                if(it->size() < 1) continue;
                it->template forward_segments<contourklip::LINE>(add_line_segment);
                it->template forward_segments<contourklip::CUBIC_BEZIER>(add_curve_segment);
                //the input should be const, hence we don't actually close it.
                if (!it->is_closed()) {
                    add_line_segment(it->front_point(), it->back().point());
                }
            }

            currpolygon = detail::CLIPPING;
            contour_idx = 0;
            for (auto it = b.begin(); it != b.end(); ++it, ++contour_idx) {
                if(it->size() < 1) continue;
                it->template forward_segments<contourklip::LINE>(add_line_segment);
                it->template forward_segments<contourklip::CUBIC_BEZIER>(add_curve_segment);
                if (!it->is_closed()) {
                    add_line_segment(it->front_point(), it->back().point());
                }
            }
        }

        bool intersect_all_segments(
                const LineSegmentIt &lines_begin, const LineSegmentIt &lines_end,
                const CurveSegmentIt &curves_begin, const CurveSegmentIt &curves_end,
                const Config &config,
                std::set<IntersectionValue> &out) {
            bool success = true;
            // lines against lines
            std::size_t i = 0;
            auto add = [&out](const IntersectionValue &t) {
                out.insert(t);
            };
            for (auto it = lines_begin; it != lines_end; ++it, ++i) {
                IntersectionValue curr_start{0., (*it).seg.first, {(*it).ptype, false, i}};
                IntersectionValue curr_end{1., (*it).seg.second, {(*it).ptype, false, i}};
                add(curr_start);
                add(curr_end);

                std::size_t j = i + 1;
                auto jt = it;
                ++jt;
                for (; jt != lines_end; ++jt, ++j) {
                    if (auto val = intersect_segments((*it).seg, (*jt).seg)) {
                        Point2d mapped = val->p;
                        double t1 = val->t1;
                        double t2 = val->t2;

                        if (t1 > 0 && t1 < 1.) {
                            SegIndent curr{(*it).ptype, false, i};
                            add(IntersectionValue{t1, mapped, curr});
                        }
                        if (t2 > 0 && t2 < 1.) {
                            SegIndent curr{(*jt).ptype, false, j};
                            add(IntersectionValue{t2, mapped, curr});
                        }
                    }
                }
            }
            i = 0;
            auto a_it = lines_begin;
            // curves against lines
            for (auto it = curves_begin; it != curves_end; ++it, ++i, ++a_it) {
                IntersectionValue curr_start{0., (*it).seg.p0, {(*it).ptype, true, i}};
                IntersectionValue curr_end{1., (*it).seg.p3, {(*it).ptype, true, i}};
                add(curr_start);
                add(curr_end);
                std::size_t j = 0;
                for (auto jt = lines_begin; jt != lines_end; ++jt, ++j) {
                    auto add_val = [&](double t, double u, Point2d p) {
                        bool parametric_ok = !std::isnan(u) || !std::isinf(u);
                        bool intersection_ok = approx_equal(beziermap((*it).seg, u),
                                                            linear_map((*jt).seg, t),
                                                            1e-4);
                        success = parametric_ok && intersection_ok;
                        IntersectionValue curr_line{t, p, {(*jt).ptype, false, j}};
                        IntersectionValue curr_curve{u, p, {(*it).ptype, true, i}};
                        add(curr_line);
                        add(curr_curve);
                    };
                    line_bezier_inter((*jt).seg, (*it).seg, add_val);
                    if (!success) return false;
                }
            }
            i = 0;
            // curves against curves
            for (auto it = curves_begin; it != curves_end; ++it, ++i) {
                std::size_t j = i + 1;
                auto jt = it;
                ++jt;
                for (; jt != curves_end; ++jt, ++j) {
                    auto add_val = [&](double t, double u, Point2d p) {
                        Point2d interp = beziermap((*it).seg, t);
                        Point2d interp2 = beziermap((*jt).seg, u);
                        bool parametric_ok = !std::isnan(u) && !std::isinf(u);
                        bool intersection_ok = approx_equal(interp, interp2, 1e-4);
                        success = parametric_ok && intersection_ok;
                        // we use inter. point of first curve
                        IntersectionValue a{t, p, {(*it).ptype, true, i}};
                        IntersectionValue b{u, p, {(*jt).ptype, true, j}};
                        add(a);
                        add(b);
                    };
                    curve_curve_inter<decltype(add_val), double, CollinearFunc>((*it).seg, (*jt).seg, add_val);
                    if (!success) return false;
                }
            }
            return true;
        }

        void init_queue() noexcept {
            std::size_t k = 1;
            auto prev_it = inters_.begin();
            auto it = prev_it;
            ++it;
            while (it != inters_.end() && k < inters_.size()) {
                while (it != inters_.end() && k < inters_.size() && (*prev_it).id == (*it).id) {
                    IntersectionValue prev = (*prev_it);
                    IntersectionValue curr = (*it);
                    if (!curr.id.curve) {
                        // although the intersections are sorted with t values,
                        // it does not guarantee that the second is on the right of the first.
                        if (!increasing(prev.p, curr.p)) {
                            std::swap(prev, curr);
                        }
                        auto *a = add_sweep_point(true, prev.p, nullptr);
                        auto *b = add_sweep_point(false, curr.p, a);
                        //setting the correct fields
                        a->other_point = b;
                        a->ptype = prev.id.ptype;
                        b->ptype = curr.id.ptype;
                        a->contourid = b->contourid = lines_[curr.id.idx].contourid;
                        //setting to some useful value. this is important when comparing sweeppoints.
                        a->controlp = b->point;
                        b->controlp = a->point;
                        queue_.push_back(a);
                        queue_.push_back(b);
                    } else {
                        // we need to split curves into monotonic segments
                        auto maybebezier = sub_bezier(curves_[curr.id.idx].seg,
                                                      prev.t_val, curr.t_val);
                        if (!maybebezier) {
                            this->bad_ = true;
                            return;
                        }
                        CubicBezier currbezier = *maybebezier;
                        // this is for consistency
                        currbezier.p0 = prev.p;
                        currbezier.p3 = curr.p;

                        double t_prev = 0.;
                        SweepPoint *first = nullptr;

                        Extremity_Direction d_prev;

                        auto process_f = [&](double t, Extremity_Direction d) {
                            auto maybemonoton = sub_bezier(currbezier, t_prev, t);
                            if (!maybemonoton) {
                                this->bad_ = true;
                                return;
                            }
                            CubicBezier monoton = *maybemonoton;
                            auto *a = add_sweep_point(false, monoton.p0, nullptr);
                            auto *b = add_sweep_point(false, monoton.p3, a);
                            a->controlp = monoton.p1;
                            b->controlp = monoton.p2;

                            // consistency regarding inner control points. tangents are either horizontal or vertical.
                            if (t != 1.) {
                                if (d == X_Extremity) {
                                    b->controlp = {b->point.x(), b->controlp.y()};
                                } else if (d == Y_Extremity) {
                                    b->controlp = {b->controlp.x(), b->point.y()};
                                }
                            }
                            if (t_prev != 0.) {
                                if (d_prev == X_Extremity) {
                                    a->controlp = {a->point.x(), a->controlp.y()};
                                } else if (d_prev == Y_Extremity) {
                                    a->controlp = {a->controlp.x(), a->point.y()};
                                }
                            }
                            a->initial_controlp = currbezier.p1;
                            b->initial_controlp = currbezier.p2;

                            a->curve = b->curve = true;
                            a->other_point = b;
                            a->ptype = b->ptype = curr.id.ptype;
                            a->contourid = b->contourid = curves_[curr.id.idx].contourid;
                            a->set_if_left();

                            if (t_prev == 0.) {
                                a->islast = true;
                                first = a;
                            }
                            if (t == 1.) {
                                b->islast = true;
                            }
                            a->start = first;
                            b->start = first;
                            queue_.push_back(a);
                            queue_.push_back(b);
                            t_prev = t;
                            d_prev = d;
                        };
                        bezier_monotonic_split(currbezier, process_f);
                        // last segment
                        process_f(1, X_Extremity);
                    }
                    it++;
                    prev_it++;
                    k++;
                }
                if (it == inters_.end()) {
                    break;
                }
                it++;
                prev_it++;
                k++;
            }
        }

        SweepPoint *add_sweep_point(bool left, const Point2d &p, SweepPoint *other) {
            return &resource_holder_.emplace_back(left, p, other);
        }

        void compute_fields(SweepPoint *curr,
                            const sline_iterator_t& prev) {
            if (prev != sline_.end()) {
                if (curr->ptype == (*prev)->ptype) {
                    curr->in_out = !(*prev)->in_out;
                    curr->other_in_out = (*prev)->other_in_out;

                } else {
                    curr->in_out = !(*prev)->other_in_out;
                    curr->other_in_out = (*prev)->vertical() ? !(*prev)->in_out : (*prev)->in_out;

                    if (overlapping(curr, (*prev))) {
                        if (curr->in_out == (*prev)->in_out) {
                            curr->edgetype = detail::SAME_TRANSITION;
                            (*prev)->edgetype = detail::SAME_TRANSITION;
                        } else {
                            curr->edgetype = detail::DIFFERENT_TRANSITION;
                            (*prev)->edgetype = detail::DIFFERENT_TRANSITION;
                        }
                        // a duplicate edge is added at most once.
                        // Therefore, we set the previous in result to false, and it is then
                        // decided if the current is in the result.

                        (*prev)->in_result[0] = false;
                        (*prev)->in_result[IMPL_INTERSECTION_] = false;
                        (*prev)->in_result[IMPL_DIFFERENCE_2_] = false;
                    }
                }

                curr->prev_in_result[0] = (!(*prev)->in_result[0]
                                        || (*prev)->vertical()) ? (*prev)->prev_in_result[0] : *prev;
                curr->prev_in_result[IMPL_INTERSECTION_] = (!(*prev)->in_result[IMPL_INTERSECTION_]
                                        || (*prev)->vertical()) ? (*prev)->prev_in_result[IMPL_INTERSECTION_] : *prev;
                curr->prev_in_result[IMPL_DIFFERENCE_2_] = (!(*prev)->in_result[IMPL_DIFFERENCE_2_]
                                        || (*prev)->vertical()) ? (*prev)->prev_in_result[IMPL_DIFFERENCE_2_] : *prev;
            }
                //special case: no predecessor
            else {
                curr->in_out = false;
                curr->other_in_out = true;
            }
            curr->in_result[0] = in_result(curr, used_clippingop_);
            curr->in_result[IMPL_INTERSECTION_] = in_result(curr, IMPL_INTERSECTION_);
            curr->in_result[IMPL_DIFFERENCE_2_] = in_result(curr, IMPL_DIFFERENCE_2_);
        }

        bool in_result(SweepPoint *curr, PolyClip::BooleanOpTypeImpl clippingop) {
            // We have to check if the edge lies inside or outside the other polygon.
            // Then, it depends on the boolean operation:
            //
            // intersection:    we select the edges which are inside the other polygon.
            // union:           we select the edges which are outside the other polygon.
            // subtract A - B:  we select the outside edges from A and the inside edges from B.
            // xor:             every edge is in the result.
            //
            // If the closest other edge is an outside inside transition, then current edge is inside
            // the other polygon, otherwise outside. We also have to treat the special case with duplicate edges.

            switch (curr->edgetype) {
                case detail::NORMAL:
                    switch (clippingop) {
                        case IMPL_INTERSECTION_:
                            return !curr->other_in_out;
                        case IMPL_UNION_:
                            return curr->other_in_out;
                        case IMPL_DIFFERENCE_:
                            return (curr->ptype == detail::SUBJECT && curr->other_in_out) ||
                                   (curr->ptype == detail::CLIPPING && !curr->other_in_out);
                        case IMPL_DIFFERENCE_2_:
                            return (curr->ptype == detail::SUBJECT && !curr->other_in_out) ||
                                   (curr->ptype == detail::CLIPPING && curr->other_in_out);
                        case IMPL_XOR_:
                            return true;
                    }
                case detail::SAME_TRANSITION:
                    return clippingop == IMPL_INTERSECTION_ || clippingop == IMPL_UNION_;
                case detail::DIFFERENT_TRANSITION:
                    return clippingop == IMPL_DIFFERENCE_ || clippingop == IMPL_DIFFERENCE_2_;
                default:
                    return false;
            }
            return true;
        }

        void connect_edges(int optype_idx=0) {
            std::vector<SweepPoint *> sorted_result{};

            int k = 0;
            for (auto sp: queue_) {
                if (sp->in_result[optype_idx]) {
                    sorted_result.push_back(sp);
                    sp->pos = k;
                    k++;
                }
            }

            if (sorted_result.size() <= 2) return;
            std::vector<bool> processed(sorted_result.size(), false);
            std::vector<std::size_t> depth{};
            std::size_t contourId;
            for (std::size_t i = 0; i < sorted_result.size(); ++i) {
                if (processed[i]) {
                    continue;
                }
                contourId = depth.size();
                depth.push_back(0); // we first assume depth[result_contour_id] is an outer contour
                Contour c{};

                compute_contour(sorted_result[i], c, contourId, processed, sorted_result);
                if (!success()) { return; }

                if (c.size() < 3) {
                    continue;
                }
                SweepPoint* previnresult = sorted_result[i]->prev_in_result[optype_idx];
                if (previnresult) {
                    std::size_t lowercontourId = previnresult->result_contour_id;
                    if (!previnresult->result_in_out) {
                        depth[contourId] = depth[lowercontourId] + 1;
                    }
                }

                bool reverse = depth[contourId] % 2 == 1;
                if (config_.postprocess) {
                    auto add = [&](Contour &t) {
                        add_contour(t, ((contour_area(t) > 0) == reverse));
                    };
                    postprocess_contour<decltype(add), CollinearFunc>(c, add, config_.postprocess_collinear);
                } else {
                    add_contour(c, reverse);
                }
            }
        }

        void compute_contour(SweepPoint *sp, Contour &c, std::size_t contourId,
                             std::vector<bool> &processed,
                             const std::vector<SweepPoint *> &sorted_result) {
            std::size_t currpos;
            Point2d startpoint = sp->point;
            c.push_back(startpoint);
            processed[sp->pos] = true;
            sp->result_contour_id = contourId;
            sp->other_point->result_contour_id = contourId;

            currpos = sp->other_point->pos;
            CONTOURKLIP_IF_NOT(currpos > 0 && currpos < sorted_result.size(), "currpos should be valid index") {
                this->bad_ = true;
                return;
            }
            processed[currpos] = true;
            //note that we are necessarily starting with the lowest left edge
            sp->result_in_out = false;
            sp->other_point->result_in_out = false;

            std::size_t k = 0;
            bool cycle = false;

            while (sorted_result[currpos]->point != startpoint && !cycle && k < sorted_result.size()) {
                if (sorted_result[currpos]->curve) {
                    if (sorted_result[currpos]->islast) {
                        c.push_back(sorted_result[currpos]->other_point->initial_controlp,
                                    sorted_result[currpos]->initial_controlp, sorted_result[currpos]->point);
                    }
                } else {
                    c.push_back(sorted_result[currpos]->point);
                }
                sorted_result[currpos]->result_contour_id = contourId;
                sorted_result[currpos]->other_point->result_contour_id = contourId;
                //if we're traversing from left to right, we're at a right point, hence we
                // don't have an inout transition.
                sorted_result[currpos]->result_in_out
                        = sorted_result[currpos]->other_point->result_in_out = sorted_result[currpos]->left;

                std::size_t npos;
                if (auto maybe_npos = nextpos(currpos, processed, sorted_result)) {
                    npos = sorted_result[*maybe_npos]->other_point->pos;
                } else {
                    this->bad_ = true;
                    return;
                }

                // we need to detect cycles, but we cannot break because
                // we have to properly set the processed[] entries.
                cycle = (npos == currpos);
                currpos = npos;
                processed[sorted_result[currpos]->pos] = true;
                //if we have processed left, we also have processed right
                processed[sorted_result[currpos]->other_point->pos] = true;
                k++;
            }
            sorted_result[currpos]->result_in_out
                    = sorted_result[currpos]->other_point->result_in_out = true;

            // close the contour.
            if (sorted_result[currpos]->curve) {
                //special case: the first and last components (ie their monotonic segments) are from the same curve
                //since it has already been included, we only need to change the starting point
                if (sp->curve && sp->start == sorted_result[currpos]->start) {

                    c.front().point() = c.back().point();
                } else {
                    c.push_back(sorted_result[currpos]->other_point->initial_controlp,
                                sorted_result[currpos]->initial_controlp, sorted_result[currpos]->point);
                }
            } else {
                c.push_back(sorted_result[currpos]->point);
            }
        }

        std::optional<std::size_t> nextpos(std::size_t currpos, const std::vector<bool> &processed,
                                                            const std::vector<SweepPoint *> &sorted_result) {
            //we first try to find one which is from another contour
            std::size_t npos = currpos;
            npos++;

            while (npos < sorted_result.size()
                   && sorted_result.at(npos)->point == sorted_result.at(currpos)->point) {
                if (!processed.at(npos)) {
                    return npos;
                }
                npos++;
            }
            npos = currpos;
            npos--;

            while (npos > 0
                   && sorted_result.at(npos)->point ==
                      sorted_result.at(currpos)->point) {
                if (!processed.at(npos)) {
                    return npos;
                }
                npos--;
            }

            npos = currpos;
            npos++;
            while (npos < sorted_result.size()
                   && sorted_result.at(npos)->point == sorted_result.at(currpos)->point) {
                if (!processed.at(npos)) {
                    return npos;
                }
                npos++;
            }
            npos = currpos;
            npos--;
            while (npos > 0
                   && sorted_result.at(npos)->point == sorted_result.at(currpos)->point) {
                if (!processed.at(npos)) {
                    return npos;
                }
                npos--;
            }

            CONTOURKLIP_IF_NOT(true, "issue finding next position") {
                this->bad_ = true;
            }

            return {};
        }

        void add_contour(Contour &c, bool reverse) {
            if (reverse) {
                c.reverse();
            }
            resultpoly.push_back(c);
        }

        void queue_correctness() {
            int count = 1;
            for (std::size_t i = 1; i < queue_.size(); ++i) {
                CONTOURKLIP_IF_NOT(queue_.at(i)->point.x() >= queue_.at(i - 1)->point.x(),
                                 "queue_ needs to be sorted") {
                    this->bad_ = true;
                    return;
                }

                if (config_.fail_on_approx_equal) {
                    CONTOURKLIP_IF_NOT(!approx_equal(queue_.at(i)->point, queue_.at(i)->other_point->point,
                                                     config_.approx_equal_tol),
                                     "other point should not be approx. equal to current point") {
                        this->bad_ = true;
                        return;
                    }

                    CONTOURKLIP_IF_NOT((queue_.at(i)->point == queue_.at(i - 1)->point
                                      || !approx_equal(queue_.at(i)->point, queue_.at(i - 1)->point,
                                                       config_.approx_equal_tol)),
                                     "points should not be almost the same, otherwise possible numerical issue"
                    ) {
                        this->bad_ = true;
                        return;
                    }
                }

                CONTOURKLIP_IF_NOT(queue_.at(i)->point.x() >= queue_.at(i)->other_point->point.x() || queue_.at(i)->left,
                                 "right point of the same segment comes after left point") {
                    this->bad_ = true;
                    return;
                }
                if (queue_.at(i)->point == queue_.at(i - 1)->point) {
                    CONTOURKLIP_IF_NOT(((!queue_.at(i - 1)->left) || queue_.at(i)->left),
                                     "right points should come before left points"
                    ) {
                        this->bad_ = true;
                        return;
                    }
                    count++;
                } else {
                    CONTOURKLIP_IF_NOT(count % 2 == 0, "same points should occur an even number of times") {
                        this->bad_ = true;
                        return;
                    }
                    count = 1;
                }
            }
        }

        void sweep() {
            for (std::size_t k = 0; k < queue_.size(); ++k) {
                SweepPoint *curr = queue_.at(k);

                if (curr->left) {
                    auto it = sline_.insert(curr);

                    if (!it.second) {
                        this->bad_ = true;
                        return;
                    }

                    other_iters_[k] = it.first;
                    curr->other_point->other_iter_pos = k;
                    auto prev = sline_.end();
                    //there's a valid predecessor
                    if (it.first != sline_.begin()) {
                        prev = it.first;
                        prev--;
                    }
                    compute_fields(curr, prev);
                } else {
                    auto it2 = other_iters_[curr->other_iter_pos];
                    auto it = sline_.find(curr->other_point);
                    if (it != it2) {
                        this->bad_ = true;
                        return;
                    }
                    sline_.erase(it);

                    curr->in_result[0] = curr->other_point->in_result[0];
                    curr->in_result[IMPL_INTERSECTION_] = curr->other_point->in_result[IMPL_INTERSECTION_];
                    curr->in_result[IMPL_DIFFERENCE_2_] = curr->other_point->in_result[IMPL_DIFFERENCE_2_];
                }
            }
        }

        void init_op_enum() {
            switch (initial_clippingop) {
                case INTERSECTION:
                    used_clippingop_ = IMPL_INTERSECTION_;
                    break;
                case UNION:
                    used_clippingop_ = IMPL_UNION_;
                    break;
                case DIFFERENCE:
                    used_clippingop_ = IMPL_DIFFERENCE_;
                    break;
                case XOR:
                    used_clippingop_ = IMPL_DIFFERENCE_;
                    break;
                case DIVIDE:
                    used_clippingop_ = IMPL_DIFFERENCE_;
                    break;
            }
        }
    };

#undef CONTOURKLIP_IF_NOT

    bool clip(const std::vector<Contour> &a, const std::vector<Contour> &b,
              std::vector<Contour> &result, BooleanOpType clippingop) {
        PolyClip c(a, b, result, clippingop);
        c.compute();
        return c.success();
    }

    bool clip(const Contour &a, const Contour &b,
              std::vector<Contour> &result, BooleanOpType clippingop) {
        std::vector poly1{a}, poly2{b};
        PolyClip c(poly1, poly2, result, clippingop);
        c.compute();
        return c.success();
    }
}
#endif //CONTOURKLIP_POLYCLIP_HPP

#endif //CONTOURKLIP_CONTOURKLIP_HPP