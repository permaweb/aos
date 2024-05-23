import { dryrun } from "@permaweb/aoconnect";
import chalk from "chalk";

export async function performDryRun(input, pid, data, owner, id, anchor) {
  await processInput(input, pid, data, owner, id, anchor);
}

async function extractTags(input, pid) {
  let tags = [];

  // Check if the input contains curly braces
  if (!input.includes("{")) {
    throw new Error("Tags not specified");
  }

  // Check if the input contains curly braces
  if (input.includes("{")) {
    try {
      // Extracting content within curly braces
      const content = input.match(/\{(.*?)\}/)[1];

      const pairs = content.split(",");

      // Iterating through each key-value pair
      pairs.forEach((pair) => {
        // Check if the pair contains an equal sign
        if (pair.includes("=")) {
          // Splitting each pair by "=" to get key and value
          const [key, value] = pair.split("=").map((item) => item.trim());
          // Normalize the value
          let normalizedValue = value;
          normalizedValue = normalizedValue.replace(/^['"](.*)['"]$/, "$1");

          console.log("normalizedValue", normalizedValue);

          // Replace "ao.id" with `pid`
          if (normalizedValue === "ao.id") {
            normalizedValue = pid;
          }

          //use extra quotes to use the "ao.id" word itself
          if (normalizedValue === "'ao.id'" || normalizedValue === `ao.id"`) {
            normalizedValue = "ao.id";
          }

          // Pushing key-value pair to tags array
          tags.push({ name: key, value: normalizedValue });
        } else {
          const action = pair.trim().replace(/^'|'$/g, "");
          tags.push({ name: "Action", value: action });
        }
      });
    } catch (error) {
      throw new Error("Invalid Syntax Usage");
    }
  } else {
    // If no curly braces, assume single word input, set it as Action
    const action = input.trim().replace(/^'|'$/g, "");
    let normalizedAction = action;
    normalizedAction = normalizedAction.replace(/^['"](.*)['"]$/, "$1");
    console.log(normalizedAction);
    tags.push({ name: "Action", value: normalizedAction });
  }

  // Adding default Target if not already present
  let targetIncluded = tags.some((tag) => tag.name === "Target");
  if (!targetIncluded) {
    tags.unshift({ name: "Target", value: pid });
  }

  return tags;
}

async function callDryRun(input, pid, data, owner, id, anchor) {
  try {
    const tags = await extractTags(input, pid);
    // check for Pid and data in params
    const customProcessId = getCustomProcessId(input, pid) || pid;
    const customData = getCustomData(input, pid) || data;

    const dryrunParams = {
      process: customProcessId,
      tags,
      ...(customData && { data: customData }),
      ...(owner && { Owner: owner }),
      ...(id && { Id: id }),
      ...(anchor && { anchor: anchor }),
    };

    checkForVerboseFlag(input, dryrunParams);

    const result = await dryrun(dryrunParams);
    return result;
  } catch (error) {
    console.error(chalk.red("Error Performing DryRun:", error.message));
  }
}

function checkForVerboseFlag(input, dryrunParams) {
    const regex = /(^|\s)-v($|\s)/; // Regular expression to match -v preceded and followed by whitespace or string boundary

    if (regex.test(input)) {
        console.log("dryrunParams:", dryrunParams);
    }
}


const getCustomProcessId = (input, pid) => {
  const match = input.match(/-p=(["'])(.*?)\1/);
  if (match) {
    let customProcessParam = match[2];

    // Replace "ao.id" with `pid`
    if (customProcessParam === "ao.id") {
      customProcessParam = pid;
    }

    if (customProcessParam.length !== 43) {
      throw new Error("Invalid Process Id");
    }
    return customProcessParam;
  }
  return null;
};

const getCustomData = (input, pid) => {
  try {
    let match = input.match(/-d=(["'])(.*?)\1/);
    if (match) {
      if (match[2] === "ao.id") {
        return pid;
      }

      if (match[2] === "'ao.id'" || match[2] === `"ao.id"`) {
        return "ao.id";
      }

      return match[2];
    }
  } catch (error) {
    throw new Error("Invalid Data Format");
  }
  return null;
};

const getSpecificResult = (obj, path, defaultValue = undefined) => {
  const travel = (regexp) =>
    String.prototype.split
      .call(path, regexp)
      .filter(Boolean)
      .reduce(
        (res, key) => (res !== null && res !== undefined ? res[key] : res),
        obj,
      );

  const result = travel(/[,[\]]+?/) || travel(/[,[\].]+?/);
  return result === undefined || result === obj ? defaultValue : result;
};

async function processInput(input, pid, data, owner, id, anchor) {
  try {
    const flagIndex = input.indexOf("-r");
    const flag = flagIndex !== -1 ? getFlag(input, flagIndex) : null;
    const result = await callDryRun(input, pid, data, owner, id, anchor);
    console.log(chalk.green("result:"));
    flag ? console.log(getSpecificResult(result, flag)) : console.log(result);
  } catch (error) {
    console.error(chalk.red("Error Processing Input:", error.message));
  }
}

const getFlag = (input, flagIndex) => {
  const flagStart = flagIndex + 3;
  const flagEnd = input.indexOf(" ", flagStart);
  return input.slice(flagStart, flagEnd !== -1 ? flagEnd : undefined).trim();
};
