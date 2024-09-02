import fs from 'fs';

const historyFilePath = (processId) => `${processId}.history`;

export const readHistory = (processId) => {
  const filePath = historyFilePath(processId);
  if (fs.existsSync(filePath)) {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  }
  return [];
};

export const writeHistory = (processId, history) => {
    const filePath = historyFilePath(processId);

    try {
        const historyToSave = history.slice(-100);  // Only save the last 100 commands
        fs.writeFileSync(filePath, JSON.stringify(historyToSave, null, 2));
    } catch (err) {
        console.error('Error writing history file:', err);
    }
};