# TeamPicker

## Setup

Before building the project, you need to configure your Apple Developer Team ID:

1. Create a file named `Local.xcconfig` in the project root
2. Add the following content, replacing `<YOUR_TEAM>` with your actual Apple Developer Team ID:
   ```
   // Local developer configuration - do not commit
   DEVELOPMENT_TEAM = <YOUR_TEAM>
   ```

To find your Team ID:
- Open Xcode Preferences > Accounts
- Select your Apple ID
- Click on your team name - the Team ID will be shown in parentheses

Note: `Local.xcconfig` is git-ignored and should not be committed.