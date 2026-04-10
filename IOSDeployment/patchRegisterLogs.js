const fs = require('fs');

const registerViewPath = "C:\\Users\\sadhe\\Downloads\\BoAnalystNative\\IOSDeployment\\swift\\Auth\\RegisterView.swift";

let code = fs.readFileSync(registerViewPath, 'utf8');
code = code.replace(
    /if nsErr\.code != ASAuthorizationError\.canceled\.rawValue \{\s*authViewModel\.uiState\.error = "Sign in with Apple failed\. Please try again\."\s*\}/g,
    `if nsErr.code != ASAuthorizationError.canceled.rawValue {
                authViewModel.uiState.error = "Native Apple Block [\\(nsErr.code)]: \\(error.localizedDescription)"
            }`
);

code = code.replace(
    /else \{\s*authViewModel\.uiState\.error = "Sign in with Apple failed\. Please try again\."\s*return\s*\}/g,
    `else {
                authViewModel.uiState.error = "Native Data Missing: Identity token could not be parsed."
                return
            }`
);
fs.writeFileSync(registerViewPath, code);
console.log('PATCH REGISTER SUCCESS');
