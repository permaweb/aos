import os from 'node:os'
import path from 'node:path'
import { spawn } from 'node:child_process'
import fs from 'node:fs'

export function pad(pid, callback) {
  const tempFilePath = path.join(os.homedir(), `.pad-${pid}.lua`);

  const editor = process.env.EDITOR || (process.platform === 'win32' ? 'notepad' : 'vi');
  const child = spawn(editor, [tempFilePath], {
    stdio: 'inherit', // This ensures the editor uses the same terminal
    shell: true,      // For Windows compatibility
  });

  child.on('exit', (exitCode) => {
    console.log('Exit Code', exitCode)
    const editedContent = fs.readFileSync(tempFilePath, 'utf8');
    callback(null, editedContent);
  });
}

