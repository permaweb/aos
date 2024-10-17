import { test, describe } from "node:test";
import * as assert from "node:assert";
import AoLoader from "@permaweb/ao-loader";
import fs from "fs";

const wasm = fs.readFileSync("./process.wasm");
const options = { format: "wasm64-unknown-emscripten-draft_2024_02_15" };

describe("state", async () => {
  test("check state properties for aos", async () => {
    const handle = await AoLoader(wasm, options);
    const env = {
      Process: {
        Id: "AOS",
        Owner: "FOOBAR",
        Tags: [{ name: "Name", value: "Thomas" }],
      },
    };
    const msg = {
      Target: "AOS",
      From: "FOOBAR",
      Owner: "FOOBAR",
      From: "FOOBAR",
      ["Block-Height"]: "1000",
      Id: "1234xyxfoo",
      Module: "WOOPAWOOPA",
      Tags: [{ name: "Action", value: "Eval" }],
      Data: 'print("name: " .. Name .. ", owner: " .. Owner)',
    };
    const result = await handle(null, msg, env);

    assert.equal(result.Output?.data, "name: Thomas, owner: FOOBAR");
    assert.ok(true);
  });

  test("test authorities", async () => {
    const handle = await AoLoader(wasm, options);
    const env = {
      Process: {
        Id: "AOS",
        Owner: "FOOBAR",
        Tags: [
          { name: "Name", value: "Thomas" },
          { name: "Authority", value: "BOOP" },
        ],
      },
    };
    const msg = {
      Target: "AOS",
      Owner: "BEEP",
      From: "BAM",
      ["Block-Height"]: "1000",
      Id: "1234xyxfoo",
      Module: "WOOPAWOOPA",
      Tags: [{ name: "Action", value: "Eval" }],
      Data: "1 + 1",
    };
    const result = await handle(null, msg, env);
    assert.ok(
      result.Output.data.includes(
        "Message is not trusted! From: BAM - Owner: BEEP",
      ),
    );
  });

  test("test program state", async () => {
    const antLua = fs.readFileSync("./aos-bundled.lua", "utf8");
    const handle = await AoLoader(wasm, options);
    const env = {
      Process: {
        Id: "AOS",
        Owner: "FOOBAR",
        Tags: [
          { name: "Name", value: "Thomas" },
          { name: "Authority", value: "BOOP" },
        ],
      },
    };
    const msg = {
      Target: "AOS",
      Owner: "FOOBAR",
      From: "FOOBAR",
      ["Block-Height"]: "1000",
      Id: "1234xyxfoo",
      Module: "WOOPAWOOPA",
      Tags: [{ name: "Action", value: "Program-State" }],
    };
    const antResult = await handle(null, {...msg,
    Data: antLua,
    Tags: [{name: "Action", value: "Eval"}]
    }, env);
    const result = await handle(antResult.Memory, msg, env);
    console.dir(JSON.parse(result.Messages[0]?.Data), { depth: null });
    fs.writeFileSync("./ant-state.json", JSON.stringify(JSON.parse(result.Messages[0]?.Data), null, 2));
  });
});
