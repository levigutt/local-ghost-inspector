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
- [x] exit
- [x] goBack
- [x] refresh
- [x] assertElementPresent
- [x] assertElementNotPresent
- [x] assertElementVisible
- [x] assertElementNotVisible
- [ ] assertText
- [ ] assertNotText
- [x] assertTextPresent
- [x] assertTextNotPresent
- [ ] assertAccessibility
- [x] assertEval
- [x] pause
- [ ] store
- [ ] extract
- [x] extractEval
- [ ] execute

## known bugs and limitations

- no support for importing steps
    - testsuite must therefore be exported with imported steps included
- many test settings are ignored
    - schedule: tests run immediately regardless of schedule
    - browser: all tests run in Firefox
    - viewport size\*
- screenshot comparison is not planned

\*) window is attempted resized, but this is unreliable
