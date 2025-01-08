// Copyright (c) 2025, WSO2 LLC. (https://www.wso2.com). All Rights Reserved.
//
// This software is the property of WSO2 LLC. and its suppliers, if any.
// Dissemination of any information or reproduction of any material contained
// herein in any form is strictly forbidden, unless permitted by WSO2 expressly.
// You may not alter or remove any copyright or other notice from copies of this content.

import ballerina/lang.runtime;
import ballerina/log;
import ballerina/time;

configurable string googleSheetIdIssues = ?;
configurable string googleSheetIdPRs = ?;

public function main() returns error? {
    string todayDate = getTodayDate();
    map<ProductRepoMap>|error productRepoMapIssues = readProductRepoMap(googleSheetIdIssues);
     if productRepoMapIssues is error {
         log:printError("Error reading product repo map: " + productRepoMapIssues.message());
         return productRepoMapIssues;
     }
    check fetchAndAppendIssues(productRepoMapIssues, todayDate);

    map<ProductRepoMapPRs>|error productRepoMapPRs = getOrgRepos(googleSheetIdPRs);
    if productRepoMapPRs is error {
        log:printError("Error reading product repo map: " + productRepoMapPRs.message());
        return productRepoMapPRs;
    }
    check fetchAndAppendPrs(productRepoMapPRs, todayDate);
}

function getTodayDate() returns string {
    time:Utc dateTime = time:utcNow();
    time:Civil civilDateTime = time:utcToCivil(dateTime);
    return string `${(civilDateTime.year).toString()}-${(civilDateTime.month).toString()}-` +
        string `${(civilDateTime.day).toString()}`;
}

function fetchAndAppendIssues(map<ProductRepoMap> productRepoMapIssues, string todayDate) returns error? {
    (string|int)[][] issueValues = check processIssues(
            productRepoMapIssues,
            time:utcNow(),
            todayDate);

    log:printInfo("Appending issue data to sheets");
    foreach var issueValue in issueValues {
        string product = issueValue[1].toString();
        (string|int)[] issueValueWithoutProduct = issueValue.filter(issue => issue.toString() != product);
        check appendToProductSheet(product, googleSheetIdIssues, issueValueWithoutProduct, headerValuesIssues);
    }
    log:printInfo("Issues successfully appended to Google Sheets!");
}

function fetchAndAppendPrs(map<ProductRepoMapPRs> productRepoMapPRs, string todayDate) returns error? {
    (string|int)[][] prValuesBatches = check processPRs(
            productRepoMapPRs,
            time:utcNow(),
            todayDate);

    log:printInfo("Clearing existing data from sheets");
    foreach var prValuesBatch in prValuesBatches {
        string product = prValuesBatch[1].toString();

        runtime:sleep(1);
        boolean|error sheetPresent = checkSheetPresent(googleSheetIdPRs, product);
        if sheetPresent is boolean && sheetPresent {
            check clearSheetData(product, googleSheetIdPRs);
        }
    }

    log:printInfo("Appending PR data to sheets");
    foreach var prValuesBatch in prValuesBatches {
        string product = prValuesBatch[1].toString();

        (string|int)[] prValues = [
            prValuesBatch[0],
            prValuesBatch[2],
            prValuesBatch[3],
            prValuesBatch[4],
            prValuesBatch[5],
            prValuesBatch[6],
            prValuesBatch[7]
        ];

        // Append PRs to Google Sheets
        check appendToProductSheet(product, googleSheetIdPRs, prValues, headerValuesPRs);
    }
    log:printInfo("PRs successfully appended to Google Sheets!");
}

const headerValuesIssues = [
    "Date",
    "Repository",
    "Total Bugs",
    "Less than 1 month Bugs",
    "Older than 1 month Bugs",
    "Older than 3 months Bugs",
    "Older than 6 months Bugs",
    "Older than 1 year Bugs",
    "Total Improvements",
    "Less than 1 month Improvements",
    "Older than 1 month  Improvements",
    "Older than 3 months Improvements",
    "Older than 6 months  Improvements",
    "Older than 1 year  Improvements",
    "Total Tasks",
    "Less than 1 month Tasks",
    "Older than 1 month Tasks",
    "Older than 3 months Tasks",
    "Older than 6 months Tasks",
    "Older than 1 year Tasks",
    "Total Features",
    "Less than 1 month Features",
    "Older than 1 month Features",
    "Older than 3 months Features",
    "Older than 6 months Features",
    "Older than 1 year Features",
    "Other",
    "Unlabelled",
    "Total"
];

const headerValuesPRs = [
    "Date",
    "Repo",
    "Total PRs",
    "less than 1 week",
    "older than 1 week",
    "older than 2 weeks",
    "older than 1 month"
];
