1. You should never do the job of any part of the team - like creating their tasks or writing the code they are supposed to.

2. Re-read the AI_TEAM_IMPLEMENTATION_REQUIREMENTS.MD file. Check if your generic implementation reflects these requirements. Implement all missed requirements. In the next steps you must also check the AI team against these requirements.

2.1 Check the team. Fix appropriately any issues you observe in the AI team implementation. Document the issues in the supervizer issues checkilist. Update the requirements if needed.

3. Check if the team is stuck. Check the test team logs, progress report, etc. All required log files and progress reports must be present according to the requirements.
Use the canonical checklist and validator (do not duplicate issue definitions here):
- Read `supervisor_issues_checklist.md`
- Run: `python scripts/validate_supervisor_issues.py --project-dir <project_dir>`

3.1 Issue Discovery Process:
- Refer to `supervisor_issues_checklist.md` in the parent directory for the complete list of issues to check and the systematic investigation process.

3.2 Fixing Issues:
- Refer to `supervisor_issues_checklist.md` in the parent directory for guidelines on fixing issues.

If everything looks fine and no fixes are needed, let them run to completion. 
If not - fix any issues you observe. Fix everything in a generic way in the generic implementation. If the issue is not clear - extend the logging logic. The same issues should not happen again. Update your requirements if needed.

4. Check if any other team is running on the same project - check against the team ID. Stop all teams working simultaneously and restart the team.

5. If you have found and fixed any issues, clean up the test team directory - leave only the app requirements and infrastructure files (run_team.py), and rerun the team from scratch to test the changes you made. When a team is reset, all files in their directory must be removed EXCEPT requirements.md and run_team.py (infrastructure files needed to start the team).
Update the manifesto and team requirements to guard agains the found issues, but make sure you don'r repeat the same thing twice in them - each requirement should be defined only once in a file.

6. Clean up your own directory for any junk files and folders. Clean up your code.

7. If you witness a complete successful run of the team. First validate that the project was indeed finished and satisfies the requirements. If this is so - copy the directory with the successful run and document it in a special log file. Then rerun the team from scratch.

