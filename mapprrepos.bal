// Copyright (c) 2025, WSO2 LLC. (https://www.wso2.com). All Rights Reserved.
//
// This software is the property of WSO2 LLC. and its suppliers, if any.
// Dissemination of any information or reproduction of any material contained
// herein in any form is strictly forbidden, unless permitted by WSO2 expressly.
// You may not alter or remove any copyright or other notice from copies of this content.

import ballerina/log;
import ballerinax/github;

public type ProductRepoMapPRs record {
    string[] repoUrls;
};

map<ProductRepoMapPRs> productRepoMapPR = {};

public function getOrgRepos(string sheetId) returns map<ProductRepoMapPRs>|error {
    string[] organizations = getPROrganizations(sheetId);
    string[] productTopics = getProductTopics(sheetId);
    github:MinimalRepository[] allRepos = [];
    foreach string org in organizations {
        log:printInfo("Fetching repositories for organization: " + org);
        final int perPage = 100;
        int page = 1;
        while true {
            github:MinimalRepository[]|error repos = githubClient->/orgs/[org]/repos
                ("all", per_page = perPage, page = page);
            if repos is error {
                log:printError("Error fetching repositories: " + repos.message());
                break;
            }
            if repos.length() == 0 {
                break;
            }
            allRepos.push(...repos);
            page += 1;
        }
        log:printInfo(string `Fetched ${allRepos.length()} repositories from ${org} organization`);
    }

    foreach github:MinimalRepository repo in allRepos {
        string[]? topics = repo.topics;
        if topics is null {
            log:printInfo("No topics found for repository: " + repo.full_name);
        } else {
            foreach string repotopic in topics {
                foreach string topic in productTopics {
                    if repotopic == topic {
                        ProductRepoMapPRs? existingProduct = productRepoMapPR[topic];
                        if (existingProduct is ProductRepoMapPRs) {
                            existingProduct.repoUrls.push(repo.html_url);
                        } else {
                            productRepoMapPR[topic] = {repoUrls: [repo.html_url]};
                        }
                        break;
                    }
                }
            }
        }
    }
    log:printInfo("Repos mapped to product topics successfully");
    return productRepoMapPR;
}

function arrayIntersect(string[] array1, string[] array2) returns string[] {
    string[] intersection = [];
    foreach string item1 in array1 {
        foreach string item2 in array2 {
            if item1 == item2 {
                intersection.push(item1);
                break;
            }
        }
    }
    return intersection;
}
