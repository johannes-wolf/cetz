#import "line.typ": add,
#import "mark.typ"

#let lobf-modes = (
  "linear",
)

#let add-fit(
    data, 
    x-key: 0, y-key: 1,
    mode: "linear",
    ..arguments
) = {

    assert(mode in lobf-modes,
    message: "Invalid columnchart mode")

    assert(type(x-key) in (int, str))
    if mode == "linear" {
        assert(type(y-key) in (int, str))
    }

    let regression-fn-linear(data, x-key, y-key) = {
        // Based on : https://github.com/simple-statistics/simple-statistics/blob/main/src/linear_regression.js
        let m = 0;
        let b = 0;
        let len = data.len();

        if ( len == 1 ){
            b = data.at(0).at(y-key)
        } else {
            let sum-x  = 0
            let sum-y  = 0
            let sum-xx = 0
            let sum-xy = 0

            for entry in data {
                let x = entry.at(x-key)
                let y = entry.at(y-key)

                sum-x = sum-x + x
                sum-y = sum-y + y

                sum-xx = sum-xx + x * x
                sum-xy = sum-xy + x * y
            }

            m = (len * sum-xy - sum-x * sum-y) / (len * sum-xx - sum-x * sum-x)

            // Room to optimize below
            b = sum-y / len - (m * sum-x) / len
        }
        [#m, #b]
        return (t) => {m*t+b}
    }

    let regress-fn = (
        if mode == "linear" {regression-fn-linear}
    )

    add(regress-fn(
        data, x-key, y-key
    ), ..arguments)
}