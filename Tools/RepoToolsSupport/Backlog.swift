import Foundation

struct BacklogIssue: Codable {
    var id: String
    var title: String
    var body: String
    var dependsOn: [String]
    var acceptanceCriteria: [String]

    var githubBody: String {
        [body, "Dependencies: " + (dependsOn.isEmpty ? "None" : dependsOn.joined(separator: ", ")),
         "Acceptance criteria:\n\n" + acceptanceCriteria.map { "- [ ] " + $0 }.joined(separator: "\n"),
         "Follow AGENTS.md and attach exact software/hardware evidence. See docs/DEVELOPMENT_PLAN.md."]
            .joined(separator: "\n\n")
    }
}

enum Backlog {
    static func validate(_ issues: [BacklogIssue]) throws {
        let ids = Set(issues.map(\.id))
        try require(ids.count == issues.count, "Duplicate issue identifiers")
        for issue in issues {
            try require(!issue.title.isEmpty && !issue.body.isEmpty && !issue.acceptanceCriteria.isEmpty,
                        "Missing issue content: \(issue.id)")
            try require(issue.dependsOn.allSatisfy { ids.contains($0) }, "Unknown dependency: \(issue.id)")
            try require(!issue.dependsOn.contains(issue.id), "Self dependency: \(issue.id)")
        }
        let byID = Dictionary(uniqueKeysWithValues: issues.map { ($0.id, $0) })
        var visited: Set<String> = []
        var active: Set<String> = []
        func visit(_ id: String) throws {
            try require(!active.contains(id), "Cyclic backlog dependency at \(id)")
            if visited.contains(id) { return }
            active.insert(id)
            for dependency in byID[id]!.dependsOn { try visit(dependency) }
            active.remove(id)
            visited.insert(id)
        }
        for id in ids.sorted() { try visit(id) }
    }
}

public func importBacklog(root: URL, repository: String?, apply: Bool, runner: CommandRunner) throws {
    let issues = try readJSON([BacklogIssue].self, root: root, path: ".github/backlog.json")
    try Backlog.validate(issues)
    guard apply else {
        for issue in issues {
            print("\(issue.title) | dependencies: \(issue.dependsOn.isEmpty ? "none" : issue.dependsOn.joined(separator: ", "))")
        }
        print("Preview only. Use --repository OWNER/REPO --apply to create issues.")
        return
    }
    guard let repository, matches(repository, #"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"#) else {
        throw ToolError("--apply requires --repository OWNER/REPO")
    }
    struct ExistingIssue: Decodable { var title: String }
    let listed = try runner.run(["gh", "issue", "list", "--repo", repository, "--state", "all",
                                 "--limit", "1000", "--json", "title,number"]).checked()
    var titles = Set(try JSONDecoder().decode([ExistingIssue].self, from: Data(listed.utf8)).map(\.title))
    for issue in issues {
        if titles.contains(issue.title) {
            print("Skipping existing: \(issue.title)")
            continue
        }
        let output = try runner.run(["gh", "issue", "create", "--repo", repository, "--title", issue.title,
                                     "--body-file", "-"], input: issue.githubBody).checked()
        print(output, terminator: "")
        titles.insert(issue.title)
    }
}
