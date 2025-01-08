// Copyright (c) 2025, WSO2 LLC. (https://www.wso2.com). All Rights Reserved.
//
// This software is the property of WSO2 LLC. and its suppliers, if any.
// Dissemination of any information or reproduction of any material contained
// herein in any form is strictly forbidden, unless permitted by WSO2 expressly.
// You may not alter or remove any copyright or other notice from copies of this content.

import ballerina/log;
import ballerina/time;
import ballerinax/github;

type PRAgeCount record {|
    int olderThanOneMonth = 0;
    int olderThanTwoWeeks = 0;
    int olderThanOneWeek = 0;
    int lessThanOneWeek = 0;
|};

type PRCount record {|
    int totalPRs = 0;
    PRAgeCount age = {};
|};

const SECONDS_IN_A_DAY = 86400d;

// Process PRs for all products
public function processPRs(map<ProductRepoMap> productRepoMap, time:Utc dateTime, string todayDate) returns error|
    (string|int)[][] {
    (string|int)[][] prValues = [];

    foreach var [product, repoInfo] in productRepoMap.entries() {
        string[] repoUrls = repoInfo.repoUrls;
        log:printInfo("Fetching PRs for product: " + product);

        foreach string repoUrl in repoUrls {
            string[] ownerAndRepo = extractOwnerAndRepo(repoUrl);
            github:PullRequestSimple[] prs = getGitHubPRs(ownerAndRepo[0], ownerAndRepo[1]);
            PRCount prCount = check countPRsByAge(prs, dateTime);
            if prCount.totalPRs > 0 {
                prValues.push([
                    todayDate,
                    product,
                    ownerAndRepo[1],
                    prCount.totalPRs,
                    prCount.age.lessThanOneWeek,
                    prCount.age.olderThanOneWeek,
                    prCount.age.olderThanTwoWeeks,
                    prCount.age.olderThanOneMonth
                ]);
            }
        }
    }
    return prValues;
}

// Fetch all the pull requests from the GitHub repository
function getGitHubPRs(string owner, string repoName) returns github:PullRequestSimple[] {
    final int perPage = 100;
    github:PullRequestSimple[] allPRs = [];
    int page = 1;

    while true {
        github:PullRequestSimple[]|error response = githubClient->/repos/[owner]/[repoName]/pulls(state = "open",
            per_page = perPage, page = page
        );
        if response is error {
            log:printError("Error fetching PRs: " + repoName + response.message());
            break;
        }
        if response.length() == 0 {
            break;
        }
        allPRs.push(...response);
        page += 1;
    }
    return allPRs;
}

// Count the PRs by their age
function countPRsByAge(github:PullRequestSimple[] prs, time:Utc dateTime) returns PRCount|error {
    PRCount cumulativePRCount = {};
    cumulativePRCount.totalPRs = prs.length();

    foreach github:PullRequestSimple pr in prs {
        string createdAtStr = pr.created_at;
        time:Utc civilTime = check time:utcFromString(createdAtStr);
        time:Seconds createdAt = time:utcDiffSeconds(dateTime, civilTime);
        decimal prDays = createdAt / SECONDS_IN_A_DAY;

        if prDays > 30d {
            cumulativePRCount.age.olderThanOneMonth += 1;
        } else if prDays >= 14d {
            cumulativePRCount.age.olderThanTwoWeeks += 1;
        } else if prDays >= 7d {
            cumulativePRCount.age.olderThanOneWeek += 1;
        } else {
            cumulativePRCount.age.lessThanOneWeek += 1;
        }
    }
    return cumulativePRCount;
}
