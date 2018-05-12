# Contributing

All contributions are welcomed for this project! Nothing is off limits.

If you found a problem, [file an issue](https://github.com/SandBlockio/satisfaction-protocol/issues/new).

If you just want to contribute, feel free to look through the [issues
list](https://github.com/SandBlockio/satisfaction-protocol/issues), or
simply submit a PR with your idea!

## Reporting Bugs

Feel free to file issues to report problems. Be sure to include:

*   Solc version
*   Truffle version
*   an example of the code

## Code style

We try to follow the [Solidity Style Guide](https://solidity.readthedocs.io/en/latest/style-guide.html), but it's currently not enforced.

## Testing

We are testing the smart contracts with Javascript in async/await style, and the Truffle framework to run them. Please write test examples for new code you create.

## Pull Requests

Please try to minimize the amount of commits in your pull request.
The goal is to keep the history readable.

Always rebase your changes onto master before submitting your PR's.

Please write [good](http://chris.beams.io/posts/git-commit/) commit messages:

*   Separate subject from body with a blank line
*   Limit the subject line to 50 characters
*   Capitalize the subject line
*   Do not end the subject line with a period
*   Use the imperative mood in the subject line
*   Wrap the body at 72 characters
*   Use the body to explain what and why vs. how

If you need to modify/squash existing commits you've made, use [rebase
interactive](https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History).

When a PR is approved, we try to merge it using GitHub's **Squash and merge** strategy, using the title as the commit message, and the remaining commits' messages and bodies as the body.

## Contribution guidelines

Smart contracts manage value and are highly vulnerable to errors and attacks. We try to follow openzeppelin guidelines, please make sure to review them: ["Contribution guidelines wiki entry"](https://github.com/OpenZeppelin/openzeppelin-solidity/wiki/Contribution-guidelines).
