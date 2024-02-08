import fs from "fs"
import path from "path"

fs.writeFileSync(
  new URL(path.join(import.meta.url, "../")),
  "hellllooo"
)