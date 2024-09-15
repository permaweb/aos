import os from 'node:os'
import path from 'node:path'
import { spawn } from 'node:child_process'
import fs from 'node:fs'
import crypto from 'node:crypto'

export function pad(pid, callback) {
  const tempFilePath = path.join(os.homedir(), `.pad-${pid}.lua`);
  let hash = null
  try {
    hash = getFileHash(tempFilePath)
  } catch (e) {
    hash = ""
  }

  const editor = process.env.EDITOR || (process.platform === 'win32' ? 'notepad' : 'vi');
  const child = spawn(editor, [tempFilePath], {
    stdio: 'inherit', // This ensures the editor uses the same terminal
    shell: true,      // For Windows compatibility
  });

  child.on('exit', (exitCode) => {
    //console.log('Exit Code: ', exitCode)
    if (exitCode == 0) {
      const editedContent = fs.readFileSync(tempFilePath, 'utf8');
      if (getFileHash(tempFilePath) !== hash) {
        callback(null, editedContent);
      } else {
        callback(new Error('no changes'))
      }
    } else {
      callback(new Error('exited'))
    }
  });
}


function getFileHash(filePath) {
  const fileBuffer = fs.readFileSync(filePath);
  const hashSum = crypto.createHash('sha256');
  hashSum.update(fileBuffer);
  return hashSum.digest('hex');
}

