import Foundation

public enum GitHub {
    public static func refresh(_ pr: PullRequest) -> PullRequest {
        var result = pr
        guard pr.url.range(of: "^https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[0-9]+$", options: .regularExpression) != nil else {
            result.error = "Unsupported pull request URL"; return result
        }
        let gh = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"].first { FileManager.default.isExecutableFile(atPath: $0) }
        guard let gh else { result.error = "Install GitHub CLI and sign in"; return result }
        do {
            let data = try Command.run(gh, ["pr", "view", pr.url, "--json", "url,title,state,reviewDecision,reviewRequests,statusCheckRollup"], timeout: 8)
            return try parse(data, url: pr.url)
        } catch { result.error = "GitHub unavailable; check gh authentication"; return result }
    }
    public static func parse(_ data: Data, url: String, now: Date = Date()) throws -> PullRequest {
        guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any], let state = o["state"] as? String else { throw PandaError.message("Invalid GitHub response") }
        var r = PullRequest(url: url); r.state = state; r.title = o["title"] as? String ?? ""; r.review = o["reviewDecision"] as? String ?? ""
        r.requestedReviewers = (o["reviewRequests"] as? [Any])?.count ?? 0
        r.checksFailed = (o["statusCheckRollup"] as? [[String: Any]] ?? []).contains { ["FAILURE", "ERROR", "TIMED_OUT", "ACTION_REQUIRED"].contains(($0["conclusion"] ?? $0["state"]) as? String ?? "") }
        r.checkedAt = now; return r
    }
}
