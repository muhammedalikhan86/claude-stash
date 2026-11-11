# Findings file format

Written by `disparity-checker` (step 6). Read by the orchestrators' Findings Intake
(`findings-intake.md`), which fills each `Intake:` line and the `Status:` line and changes nothing else.
Findings carry **no IDs**: the intake assigns them.

```markdown
# Disparity findings: <component or repo>, <scope>, <yyyy-mm-dd>

Status: open
Checked: <app-url> against <artboards-directory>, widths <parity-viewports>, at commit <short hash>
Boards: <board files checked>
Test cases: <files read, or "none found">
Harness: <parity-command | existing spec <path> | script in the evidence folder>
Evidence: <evidence folder>

## Findings

### <Title: what is wrong, in plain words, no ID>

- Screen: <screen> (<board file>, <app route>)
- State: <state(s)>; Width: <width(s)>
- Board: <board value>
- Built: <built value>
- Test case: <file §scenario: expected outcome>, or "none"
- Severity: High | Medium | Low
- Component: <owner> (<the file that renders or styles it>)
- Built by: <work item ID, or —>
- Suggested type: Bug | Design-row question | Test-case gap
- Why: <one line: for a design-row question, what was checked (kit, siblings); for a gap, which side lacks it>
- Evidence: <screenshot and measurement file names>
- Intake:

## Sifted (not findings)

| Screen | State | Element | Difference | Why sifted | Source |
|---|---|---|---|---|---|

## Unable to check

- <screen or state>: <reason>
```

## Rules

1. **Ordering:** findings by severity (High first), then by screen.
2. **`Suggested type`:**
   - `Bug`: the build differs from a board that is right, or breaks a test case's expected outcome.
   - `Design-row question`: the board looks wrong, or draws nothing for a state the test cases name.
   - `Test-case gap`: a board draws a state no test case covers.
3. **The intake marks it consumed:** `Status: consumed <yyyy-mm-dd> by run <run id>`, and each
   `Intake:` line becomes `logged as <ID>`, `design row <row ID>`, `planned: <ID>` or `declined`. A
   consumed file is never taken again; a new check writes a new file.
