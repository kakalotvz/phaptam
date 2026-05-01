export type TimingInputLine = string | { content?: string; text?: string; start_time?: number; startTime?: number };

export type ScriptureTimingLine = {
  content: string;
  start_time: number;
};

function readContent(line: TimingInputLine) {
  return typeof line === 'string' ? line : line.content ?? line.text ?? '';
}

function countWords(content: string) {
  return content.trim().split(/\s+/).filter(Boolean).length;
}

function punctuationPenalty(content: string) {
  const commas = (content.match(/[,，、;]/g) ?? []).length;
  const periods = (content.match(/[.。.!?！？]/g) ?? []).length;
  return commas * 0.3 + periods * 0.6;
}

export function normalizeScriptureLines(lines: TimingInputLine[]) {
  return lines.map((line) => readContent(line).trim()).filter(Boolean);
}

export function generateScriptureTiming(lines: TimingInputLine[], audioDuration?: number): ScriptureTimingLine[] {
  const normalized = normalizeScriptureLines(lines);
  if (normalized.length === 0) return [];

  const weights = normalized.map((content) => Math.max(1, countWords(content)) + punctuationPenalty(content));
  const totalWeight = weights.reduce((sum, weight) => sum + weight, 0);
  const totalWords = normalized.reduce((sum, content) => sum + countWords(content), 0);
  const totalDuration = audioDuration && audioDuration > 0 ? audioDuration : Math.max(1, (totalWords / 180) * 60);

  let cursor = 0;
  return normalized.map((content, index) => {
    const start_time = Number(cursor.toFixed(2));
    cursor += (weights[index] / totalWeight) * totalDuration;
    return { content, start_time };
  });
}

export function validateScriptureLines(lines: ScriptureTimingLine[]) {
  let previous = -1;
  for (const [index, line] of lines.entries()) {
    if (!line.content?.trim()) {
      throw new Error(`Dòng ${index + 1} không có nội dung`);
    }
    if (!Number.isFinite(line.start_time) || line.start_time < 0) {
      throw new Error(`Dòng ${index + 1} có thời gian không hợp lệ`);
    }
    if (line.start_time <= previous) {
      throw new Error(`Thời gian dòng ${index + 1} phải lớn hơn dòng trước`);
    }
    previous = line.start_time;
  }
}
