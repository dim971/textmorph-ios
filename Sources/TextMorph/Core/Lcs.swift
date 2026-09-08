// A port of torph's packages/torph/src/lib/utils/lcs.ts.

/// The longest common subsequence of two sequences, as paired indices.
///
/// Returns one array of indices into `a` and one into `b`, of equal length,
/// pairing the elements that survive from `a` into `b`. Everything not paired
/// is an element that leaves `a` or arrives in `b`.
///
/// The table is filled backwards and walked forwards, so a tie goes to the
/// earliest match. That is not an implementation detail: walked backwards, a
/// word that appears twice in a value pairs with the later occurrence, and the
/// segment then flies the width of the block to reach it.
func lcsIndices<Element: Equatable>(_ a: [Element], _ b: [Element]) -> ([Int], [Int]) {
    let m = a.count
    let n = b.count
    if m == 0 || n == 0 { return ([], []) }

    // dp[i][j] is the length of the longest common subsequence of a[i...] and
    // b[j...], stored flat because the tables get large and a nested array
    // costs an allocation per row.
    let stride = n + 1
    var dp = [Int](repeating: 0, count: (m + 1) * stride)

    for i in Swift.stride(from: m - 1, through: 0, by: -1) {
        for j in Swift.stride(from: n - 1, through: 0, by: -1) {
            dp[i * stride + j] = a[i] == b[j]
                ? dp[(i + 1) * stride + j + 1] + 1
                : max(dp[(i + 1) * stride + j], dp[i * stride + j + 1])
        }
    }

    var aIndices: [Int] = []
    var bIndices: [Int] = []
    var i = 0
    var j = 0
    while i < m, j < n {
        if a[i] == b[j] {
            aIndices.append(i)
            bIndices.append(j)
            i += 1
            j += 1
        } else if dp[(i + 1) * stride + j] >= dp[i * stride + j + 1] {
            i += 1
        } else {
            j += 1
        }
    }

    return (aIndices, bIndices)
}
