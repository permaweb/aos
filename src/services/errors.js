/**
 * Parse an error result string
 * @param {string} error Error result
 */
export function parseError(error) {
  // parse error message
  const errorMessage = error.replace(
    /\[string "[a-zA-Z0-9_.-]*"\]:[0-9]*: /g,
    ""
  );

  // parse line number
  const lineNumbers = error.match(/:([0-9]*):/g);
  if (!lineNumbers) return undefined;

  // (it's going to be the last ":linenumber:")
  const lineNumber = parseInt(
    lineNumbers[lineNumbers.length - 1]?.replace(/:/g, "") || 
    "1"
  );

  return {
    lineNumber,
    errorMessage
  };
}
