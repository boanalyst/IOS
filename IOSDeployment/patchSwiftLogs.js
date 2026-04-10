const fs = require('fs');

const loginViewPath = "C:\\Users\\sadhe\\Downloads\\BoAnalystNative\\IOSDeployment\\swift\\Auth\\LoginView.swift";
const authVMPath = "C:\\Users\\sadhe\\Downloads\\BoAnalystNative\\IOSDeployment\\swift\\Auth\\AuthViewModel.swift";

// Patch LoginView.swift
let loginCode = fs.readFileSync(loginViewPath, 'utf8');
loginCode = loginCode.replace(
    /if nsErr\.code != ASAuthorizationError\.canceled\.rawValue \{\s*authViewModel\.uiState\.error = "Sign in with Apple failed\. Please try again\."\s*\}/g,
    `if nsErr.code != ASAuthorizationError.canceled.rawValue {
                authViewModel.uiState.error = "Native Apple Block [\\(nsErr.code)]: \\(error.localizedDescription)"
            }`
);

loginCode = loginCode.replace(
    /else \{\s*authViewModel\.uiState\.error = "Sign in with Apple failed\. Please try again\."\s*return\s*\}/g,
    `else {
                authViewModel.uiState.error = "Native Data Missing: Identity token could not be parsed."
                return
            }`
);
fs.writeFileSync(loginViewPath, loginCode);


// Patch AuthViewModel.swift
let vmCode = fs.readFileSync(authVMPath, 'utf8');

vmCode = vmCode.replace(
    /uiState\.error = \(response\\["message"\\] as\? String\) \?\? "Sign in with Apple failed\. Please try again\."/g,
    `uiState.error = "Backend Error: " + ((response["message"] as? String) ?? "Unknown Response")`
);

fs.writeFileSync(authVMPath, vmCode);
console.log('PATCH SUCCESS');
