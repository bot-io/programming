# Dual Reader 3.2 - Requirements Roadmap

## Improvements list

Implement the following requirements. Update the requirements.md with them. Cover them with module and integration tests. Run all tests. 
Execute the playbook described CHANGE_REQUEST_PLAYBOOK.md

- Book pagination should start immediately when the book is imported. Book should be grayed out and not clickable while paginating. A progress reading will be nice.
- Changing font size/line height/margins must preserve book progress - the start position of the opened page must be the same as the start position of the opened page before the text layout change.

## Done

- When using the slider to navigate through the book, the translation must be triggered only when the user lifts their finger. While the user is dragging the slider, a value indicator is shown(in percents), so that the user can see the position to which he will move the slider.

