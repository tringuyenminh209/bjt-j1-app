import { readdir, readFile, mkdir, writeFile, copyFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const assets = path.join(root, 'mobile/assets');
await mkdir(path.join(assets, 'audio'), { recursive: true });
let audioSource = path.join(root, 'storage/app/media/hito-ugokasu-chukyu1');
try { await readdir(audioSource); } catch { audioSource = path.join(assets, 'audio'); }
const audioFiles = new Set(await readdir(audioSource));
const lessons = [];
for (const category of ['vocab', 'grammar', 'listening']) {
  for (const file of (await readdir(path.join(root, 'data', category))).sort()) {
    if (!file.endsWith('.json')) continue;
    const lesson = JSON.parse(await readFile(path.join(root, 'data', category, file), 'utf8'));
    const audio = lesson.audio?.split('/').at(-1);
    lesson.audio = audioFiles.has(audio) ? `assets/audio/${audio}` : null;
    if (lesson.audio && audioSource !== path.join(assets, 'audio')) {
      await copyFile(path.join(audioSource, audio), path.join(assets, 'audio', audio));
    }
    delete lesson.image;
    lessons.push(lesson);
  }
}
await writeFile(path.join(assets, 'lessons.json'), JSON.stringify(lessons));
console.log(`Prepared ${lessons.length} lessons; audio files available: ${audioFiles.size}`);
