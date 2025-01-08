// Copyright (c) 2025, WSO2 LLC. (https://www.wso2.com). All Rights Reserved.
//
// This software is the property of WSO2 LLC. and its suppliers, if any.
// Dissemination of any information or reproduction of any material contained
// herein in any form is strictly forbidden, unless permitted by WSO2 expressly.
// You may not alter or remove any copyright or other notice from copies of this content.

import ballerina/lang.runtime;
import ballerina/log;
import ballerinax/googleapis.sheets;

configurable string googleClientId = ?;
configurable string googleClientSecret = ?;
configurable string googleRefreshToken = ?;

final string configsSheetName = "Configs";

final sheets:ConnectionConfig spreadsheetConfig = {
    auth: {
        clientId: googleClientId,
        clientSecret: googleClientSecret,
        refreshUrl: sheets:REFRESH_URL,
        refreshToken: googleRefreshToken
    }
};

final sheets:Client spreadsheetClient = check new (spreadsheetConfig);

const SHEET_NOT_FOUND = "Sheet not found";

public type ProductRepoMap record {
    string[] repoUrls;
};

public function readProductRepoMap(string sheetId) returns map<ProductRepoMap>|error {
    map<ProductRepoMap> productRepoMap = {};
    int rowIndex = 2;

    while true {
        sheets:Row|error row = spreadsheetClient->getRow(sheetId, "Repositories", rowIndex);
        if row is error {
            log:printError("Error reading row: " + row.message());
            continue;
        }
        if row.values.length() == 0 {
            break;
        }
        string productName = row.values[0].toString();
        string repoUrl = row.values[1].toString();

        ProductRepoMap? existingProduct = productRepoMap[productName];
        if existingProduct is ProductRepoMap {
            existingProduct.repoUrls.push(repoUrl);
        } else {
            productRepoMap[productName] = {repoUrls: [repoUrl]};
        }
        rowIndex += 1;
    }

    return productRepoMap;
}

// Function to append data to a specific sheet
public function appendToProductSheet(string product, string sheetId, (string|int)[] valuesBatch,
        string[] headerValues) returns error? {
    sheets:A1Range a1Range = {sheetName: product};

    runtime:sleep(1);
    boolean|error sheetPresent = checkSheetPresent(sheetId, product);
    if sheetPresent is error {
        return sheetPresent;
    } else if sheetPresent == false {
        check createNewSheet(product, sheetId, headerValues, a1Range);
    }
    sheets:ValuesRange|error result = spreadsheetClient->appendValues(sheetId, [valuesBatch], a1Range);
    if result is error {
        log:printError("Error appending values: " + result.message() + valuesBatch[2].toString());
    }
}

// Function to clear the data from a specific sheet
public function clearSheetData(string sheetName, string sheetId) returns error? {
    error? deleteRows = spreadsheetClient->clearRange(sheetId, sheetName, "A2:L");
    if deleteRows is error {
        log:printError("Error deleting rows: " + deleteRows.message());
        return deleteRows;
    }
}

function createNewSheet(string product, string sheetId, string[] headerValues, sheets:A1Range a1Range)
        returns error? {
    log:printError(string `${product} sheet not found. Creating a new sheet`);
    sheets:Sheet|error newSheet = spreadsheetClient->addSheet(sheetId, product);
    if newSheet is error {
        log:printError(string `Error creating sheet: ${product}, ${newSheet.message()}`);
    }

    string a1Notation = "A1";
    string[][] entries = [
        headerValues
    ];
    sheets:Range range = {a1Notation: a1Notation, values: entries};

    sheets:Range|error? addHeader = spreadsheetClient->setRange(sheetId, product, range);
    if addHeader is error {
        log:printError("Error appending header: " + addHeader.message());
        return addHeader;
    }
    log:printInfo(string `${product} sheet created successfully`);
}

// Add a workaround to check if the sheet is present, https://github.com/wso2-enterprise/internal-support-ballerina/issues/860
function checkSheetPresent(string sheetId, string sheetName) returns boolean|error {
    sheets:Sheet|error sheet = spreadsheetClient->getSheetByName(sheetId, sheetName);
    if sheet is error {
        if sheet.message() == SHEET_NOT_FOUND {
            return false;
        } else {
            return error("Error checking sheet: " + sheet.message());
        }
    }
    return true;
}

function getPROrganizations(string sheetId) returns string[] {
    sheets:Range|error values = spreadsheetClient->getRange(sheetId, configsSheetName, "A2:A");
    if values is error {
        log:printError("Error reading PR organizations: " + values.message());
        return [];
    }

    string[] orgs = [];
    foreach (int|string|decimal)[] org in values.values {
        if org.length() > 0 && org[0] != "" {
            orgs.push(org[0].toString());
        }
    }
    return orgs;
}

function getProductTopics(string sheetId) returns string[] {
    sheets:Range|error values = spreadsheetClient->getRange(sheetId, configsSheetName, "E2:E");
    if values is error {
        log:printError("Error reading product topics: " + values.message());
        return [];
    }

    string[] topics = [];
    foreach (int|string|decimal)[] row in values.values {
        if row.length() > 0 && row[0] != "" {
            topics.push(row[0].toString());
        }
    }
    return topics;
}
