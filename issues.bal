import ballerina/log;
import ballerina/time;
import ballerinax/github;

configurable string githubAccessToken = ?;

type AgeCount record {|
    int lessThanOneMonth = 0;
    int olderThanOneMonth = 0;
    int olderThanThreeMonths = 0;
    int olderThanSixMonths = 0;
    int olderThanOneYear = 0;
|};

type IssueCount record {|
    int bug = 0;
    AgeCount bugAge = {};
    int improvement = 0;
    AgeCount improvementAge = {};
    int task = 0;
    AgeCount taskAge = {};
    int feature = 0;
    AgeCount featureAge = {};
    int other = 0;
    int unlabelled = 0;
    int totalIssues = 0;
|};

type GitHubIssueLabel record {
    int id?;
    string node_id?;
    string url?;
    string name?;
    string? description?;
    string? color?;
    boolean default?;
};

public enum IssueLabel {
    BUG = "Type/Bug",
    IMPROVEMENT = "Type/Improvement",
    TASK = "Type/Task",
    FEATURE = "Type/NewFeature"
}

final github:ConnectionConfig githubConfig = {
    auth: {token: githubAccessToken}
};

final github:Client githubClient = check new (githubConfig);

public function processIssues(map<ProductRepoMap> productRepoMap, time:Utc dateTime, string todayDate)
        returns (string|int)[][]|error {
    (string|int)[][] issueValues = [];

    foreach var [product, repoInfo] in productRepoMap.entries() {
        string[] repoUrls = repoInfo.repoUrls;
        log:printInfo("Fetching issues for product: " + product);

        foreach string repoUrl in repoUrls {
            [string, string] ownerAndRepo = extractOwnerAndRepo(repoUrl);
            string repoName = ownerAndRepo[1];

            github:Issue[] issuesJson = check getGitHubIssues(ownerAndRepo[0], ownerAndRepo[1]);
            IssueCount repoIssueCount = check countIssuesByLabelAndAge(issuesJson, dateTime);

            // Get the age of each issue type
            int[] bugValues = getAgeValues(repoIssueCount.bugAge);
            int[] improvementValues = getAgeValues(repoIssueCount.improvementAge);
            int[] taskValues = getAgeValues(repoIssueCount.taskAge);
            int[] featureValues = getAgeValues(repoIssueCount.featureAge);

            // Append each repository's individual issue counts to issueValues
            issueValues.push([
                todayDate,
                product,
                repoName,
                repoIssueCount.bug,
                ...bugValues,
                repoIssueCount.improvement,
                ...improvementValues,
                repoIssueCount.task,
                ...taskValues,
                repoIssueCount.feature,
                ...featureValues,
                repoIssueCount.other,
                repoIssueCount.unlabelled,
                repoIssueCount.totalIssues
            ]);
        }
    }

    return issueValues;
}

// Fetch all repository issues from GitHub
function getGitHubIssues(string owner, string repoName) returns github:Issue[]|error {
    final int perPage = 100;
    github:Issue[] allIssues = [];
    int page = 1;

    while true {
        github:Issue[]|error response = githubClient->/repos/[owner]/[repoName]/issues(state = "open",
            per_page = perPage, page = page
        );
        if response is error {
            log:printError(string `Error fetching issues in: ${repoName} with error: ${response.message()}`);
            break;
        }
        if response.length() == 0 {
            break;
        }
        allIssues.push(...response);
        page += 1;
    }

    return allIssues;
}

// Count the issues by their labels and the age
function countIssuesByLabelAndAge(github:Issue[] issues, time:Utc dateTime) returns IssueCount|error {
    IssueCount cumulativeCount = {};
    cumulativeCount.totalIssues = issues.length();

    foreach github:Issue issue in issues {
        var labels = issue.labels;

        string createdAtStr = issue.created_at;
        time:Utc civilTime = check time:utcFromString(createdAtStr);
        time:Seconds createdAt = time:utcDiffSeconds(dateTime, civilTime);
        decimal issueDays = createdAt / SECONDS_IN_A_DAY;

        if labels.length() == 0 {
            cumulativeCount.unlabelled += 1;
        } else {
            foreach var label in labels {
                string labelName = "";
                if label is GitHubIssueLabel {
                    labelName = label.name.toString();
                } else {
                    labelName = label;
                }

                countLableAge(labelName, issueDays, cumulativeCount);
            }
        }
    }

    cumulativeCount.other = cumulativeCount.totalIssues - (cumulativeCount.unlabelled + cumulativeCount.bug +
        cumulativeCount.improvement + cumulativeCount.task + cumulativeCount.feature);
    return cumulativeCount;
}

function countLableAge(string labelName, decimal issueDays, IssueCount cumulativeCount) {
    AgeCount ageCount = {};
    if labelName == BUG {
        cumulativeCount.bug += 1;
        ageCount = cumulativeCount.bugAge;
    } else if labelName == IMPROVEMENT {
        cumulativeCount.improvement += 1;
        ageCount = cumulativeCount.improvementAge;
    } else if labelName == TASK {
        cumulativeCount.task += 1;
        ageCount = cumulativeCount.taskAge;
    } else if labelName == FEATURE {
        cumulativeCount.feature += 1;
        ageCount = cumulativeCount.featureAge;
    }

    if issueDays >= 365d {
        ageCount.olderThanOneYear += 1;
    } else if issueDays >= 180d {
        ageCount.olderThanSixMonths += 1;
    } else if issueDays >= 90d {
        ageCount.olderThanThreeMonths += 1;
    } else if issueDays >= 30d {
        ageCount.olderThanOneMonth += 1;
    } else {
        ageCount.lessThanOneMonth += 1;
    }
}

function getAgeValues(AgeCount ageCount) returns int[] {
    return [
        ageCount.lessThanOneMonth,
        ageCount.olderThanOneMonth,
        ageCount.olderThanThreeMonths,
        ageCount.olderThanSixMonths,
        ageCount.olderThanOneYear
    ];
}

function extractOwnerAndRepo(string repoUrl) returns [string, string] {
    string urlWithoutRepo = repoUrl.substring(0, <int>repoUrl.lastIndexOf("/"));
    string owner = urlWithoutRepo.substring(<int>(urlWithoutRepo.lastIndexOf("/") + 1));
    string repoName = repoUrl.substring(<int>(repoUrl.lastIndexOf("/") + 1));
    return [owner, repoName];
}
