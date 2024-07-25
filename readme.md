# local ghost inspector

```sh
run-test.pl testsuite.json
```

- output is in TAP format

## implementation status

**commands**

- [x] open
- [x] click
- [x] mouseOver
- [x] assign
- [x] keypress
- [ ] screenshot
- [x] eval
- [x] exit
- [x] goBack
- [x] refresh
- [x] assertElementPresent
- [x] assertElementNotPresent
- [x] assertElementVisible
- [x] assertElementNotVisible
- [x] assertText
- [x] assertNotText
- [x] assertTextPresent
- [x] assertTextNotPresent
- [ ] assertAccessibility
- [x] assertEval
- [x] pause
- [x] store
- [x] extract
- [x] extractEval

## not to be implemented

- [ ] dragAndDrop (unclear what this even is supposed to do)
- [ ] execute (this executes a test by ID)

**built-in variables**

- [x] timestamp
- [x] alphanumeric
- [x] name.firstName
- [x] name.lastName
- [x] name.prefix
- [x] name.suffix
- [x] name.title
- [x] company.companyName
- [x] address.streetAddress
- [x] address.city
- [x] address.state
- [x] address.stateAbbr
- [x] address.zipCode
- [x] address.countryCode
- [x] phone.phoneNumber
- [x] phone.phoneNumberFormat
- [x] image.avatar
- [x] internet.email
- [x] internet.password
- [x] internet.ip
- [x] internet.color
- [x] date.month
- [x] date.weekday
- [ ] date.past
- [ ] date.future
- [x] commerce.productName
- [x] commerce.price
- [x] lorem.text
- [x] random.number
- [x] random.uuid

### extra built-in variables

- [ ] date.recent
    - within the past week
- [ ] date.soon
    - within the next week
- [ ] name.full
    - first name, last name
    - usually without title, prefix, and suffix

## known bugs and limitations

- no support for importing steps
    - you must include imported steps when exporting test suite
- many test settings are ignored
    - schedule: tests run immediately regardless of schedule
    - browser: all tests run in Firefox
- window resizing is attempted, but this is unreliable
- screenshot comparison is not planned

