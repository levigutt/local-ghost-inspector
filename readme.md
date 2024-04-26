# local ghost inspector

```sh
run-test.pl testsuite.json
```

- output is in TAP format

## implementation status of commands

- [x] open
- [x] click
- [ ] mouseOver
- [ ] dragAndDrop
- [ ] assign
- [ ] keypress
- [ ] screenshot
- [ ] eval
- [ ] exit
- [ ] goBack
- [ ] refresh
- [x] assertElementPresent
- [x] assertElementNotPresent
- [x] assertElementVisible
- [x] assertElementNotVisible
- [ ] assertText
- [ ] assertNotText
- [x] assertTextPresent
- [ ] assertTextNotPresent
- [ ] assertAccessibility
- [x] assertEval
- [x] pause
- [ ] store
- [ ] extract
- [x] extractEval
- [ ] execute

## known bugs and limitations

- tests are run in Firefox::Marionette only
    - no current plans to implement Chromium
- cannot resize window on macos (unknown cause)
- screenshot comparison is not planned

