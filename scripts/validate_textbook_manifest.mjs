import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const REGION_TYPES = new Set(['word', 'sentence', 'dialogue', 'paragraph']);
const ASSET_TYPES = new Set(['audio', 'video']);
const ASSET_ROLES = new Set([
  'reference_audio',
  'ai_reference_audio',
  'teaching_video',
  'practice_video',
]);
const ITEM_TYPES = new Set(['word', 'sentence', 'paragraph']);

async function main() {
  const cwd = process.cwd();
  const inputPaths = process.argv.slice(2);
  const manifestPaths = inputPaths.length
    ? inputPaths.map((item) => path.resolve(cwd, item))
    : await findManifestFiles(path.join(cwd, 'assets', 'textbooks'));

  if (!manifestPaths.length) {
    console.error('No textbook manifest files found.');
    process.exit(1);
  }

  let hasFailure = false;

  for (const manifestPath of manifestPaths.sort()) {
    const relativePath = path.relative(cwd, manifestPath) || manifestPath;
    try {
      const raw = await fs.readFile(manifestPath, 'utf8');
      const manifest = JSON.parse(raw);
      const summary = await validateManifest(manifest, cwd);
      console.log(
        `OK ${relativePath} (${summary.pages} pages, ${summary.regions} regions, ${summary.assets} linked assets, ${summary.assignments} assignments)`,
      );
    } catch (error) {
      hasFailure = true;
      const message = error instanceof Error ? error.message : String(error);
      console.error(`ERROR ${relativePath}: ${message}`);
    }
  }

  if (hasFailure) {
    process.exit(1);
  }
}

async function findManifestFiles(rootDir) {
  const results = [];

  async function walk(currentDir) {
    let entries = [];
    try {
      entries = await fs.readdir(currentDir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        await walk(fullPath);
        continue;
      }
      if (entry.isFile() && entry.name === 'manifest.json') {
        results.push(fullPath);
      }
    }
  }

  await walk(rootDir);
  return results;
}

async function validateManifest(manifest, cwd) {
  if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) {
    throw new Error('manifest root must be an object');
  }

  expectInteger(manifest.schemaVersion, 'schemaVersion', { min: 1 });

  const textbook = expectObject(manifest.textbook, 'textbook');
  const target = expectObject(manifest.target, 'target');
  const pages = expectArray(manifest.pages, 'pages');
  const assignments = expectArray(manifest.assignments, 'assignments');

  expectString(textbook.key, 'textbook.key');
  expectString(textbook.series, 'textbook.series');
  expectString(textbook.level, 'textbook.level');
  expectString(textbook.title, 'textbook.title');
  const assetRoot = expectPathPrefix(textbook.assetRoot, 'textbook.assetRoot', 'assets/textbooks/');
  const mediaRoot = expectPathPrefix(textbook.mediaRoot, 'textbook.mediaRoot', 'assets/media/');
  const defaultWidth = expectNumber(textbook.pageWidth, 'textbook.pageWidth', { minExclusive: 0 });
  const defaultHeight = expectNumber(textbook.pageHeight, 'textbook.pageHeight', { minExclusive: 0 });

  expectString(target.schoolCode, 'target.schoolCode');
  expectString(target.className, 'target.className');

  if (!pages.length) {
    throw new Error('pages must contain at least one page');
  }

  const pageKeys = new Set();
  const pageNumbers = new Set();
  const regionKeys = new Set();

  let regionCount = 0;
  let assetCount = 0;

  for (const [pageIndex, page] of pages.entries()) {
    const pagePath = `pages[${pageIndex}]`;
    const pageObject = expectObject(page, pagePath);
    const pageKey = expectUniqueString(pageObject.key, `${pagePath}.key`, pageKeys);
    const pageNumber = expectInteger(pageObject.pageNumber, `${pagePath}.pageNumber`, { min: 1 });
    if (pageNumbers.has(pageNumber)) {
      throw new Error(`${pagePath}.pageNumber must be unique`);
    }
    pageNumbers.add(pageNumber);
    expectString(pageObject.materialTitle, `${pagePath}.materialTitle`);
    expectString(pageObject.materialDescription, `${pagePath}.materialDescription`);
    await expectBundledAsset(pageObject.pdf, `${pagePath}.pdf`, cwd, assetRoot);
    await expectBundledAsset(pageObject.image, `${pagePath}.image`, cwd, assetRoot);
    expectNumber(pageObject.width ?? defaultWidth, `${pagePath}.width`, { minExclusive: 0 });
    expectNumber(pageObject.height ?? defaultHeight, `${pagePath}.height`, { minExclusive: 0 });

    const regions = expectArray(pageObject.regions, `${pagePath}.regions`);
    if (!regions.length) {
      throw new Error(`${pagePath}.regions must contain at least one region`);
    }

    for (const [regionIndex, region] of regions.entries()) {
      const regionPath = `${pagePath}.regions[${regionIndex}]`;
      const regionObject = expectObject(region, regionPath);
      const regionKey = expectUniqueString(
        regionObject.key,
        `${regionPath}.key`,
        regionKeys,
      );
      if (!regionKey.startsWith(pageKey)) {
        throw new Error(`${regionPath}.key should start with ${pageKey}`);
      }
      expectEnum(regionObject.type, `${regionPath}.type`, REGION_TYPES);
      expectInteger(regionObject.sortOrder, `${regionPath}.sortOrder`, { min: 1 });
      expectBoxValue(regionObject.x, `${regionPath}.x`);
      expectBoxValue(regionObject.y, `${regionPath}.y`);
      const regionWidth = expectNumber(regionObject.width, `${regionPath}.width`, {
        minExclusive: 0,
        maxInclusive: 1,
      });
      const regionHeight = expectNumber(regionObject.height, `${regionPath}.height`, {
        minExclusive: 0,
        maxInclusive: 1,
      });
      if (regionObject.x + regionWidth > 1) {
        throw new Error(`${regionPath}.x + width must be <= 1`);
      }
      if (regionObject.y + regionHeight > 1) {
        throw new Error(`${regionPath}.y + height must be <= 1`);
      }
      expectString(regionObject.displayText, `${regionPath}.displayText`);
      expectString(regionObject.promptText, `${regionPath}.promptText`);
      expectString(regionObject.expectedText, `${regionPath}.expectedText`);
      expectString(regionObject.ttsText, `${regionPath}.ttsText`);

      const assets = expectArray(regionObject.assets, `${regionPath}.assets`);
      if (!assets.length) {
        throw new Error(`${regionPath}.assets must contain at least one linked asset`);
      }

      for (const [assetIndex, asset] of assets.entries()) {
        const assetPath = `${regionPath}.assets[${assetIndex}]`;
        const assetObject = expectObject(asset, assetPath);
        const assetRole = expectEnum(assetObject.role, `${assetPath}.role`, ASSET_ROLES);
        const assetType = expectEnum(assetObject.type, `${assetPath}.type`, ASSET_TYPES);
        if (assetRole.includes('audio') && assetType !== 'audio') {
          throw new Error(`${assetPath}.type must be audio for role ${assetRole}`);
        }
        if (assetRole.includes('video') && assetType !== 'video') {
          throw new Error(`${assetPath}.type must be video for role ${assetRole}`);
        }
        await expectBundledAsset(assetObject.path, `${assetPath}.path`, cwd, mediaRoot);
        expectString(assetObject.mimeType, `${assetPath}.mimeType`);
        expectString(assetObject.provider, `${assetPath}.provider`);
        if (assetObject.durationMs != null) {
          expectInteger(assetObject.durationMs, `${assetPath}.durationMs`, { min: 1 });
        }
        assetCount += 1;
      }

      regionCount += 1;
    }
  }

  const assignmentKeys = new Set();

  for (const [assignmentIndex, assignment] of assignments.entries()) {
    const assignmentPath = `assignments[${assignmentIndex}]`;
    const assignmentObject = expectObject(assignment, assignmentPath);
    expectUniqueString(assignmentObject.key, `${assignmentPath}.key`, assignmentKeys);
    expectString(assignmentObject.title, `${assignmentPath}.title`);
    expectString(assignmentObject.description, `${assignmentPath}.description`);
    expectInteger(assignmentObject.dueOffsetDays, `${assignmentPath}.dueOffsetDays`, { min: 0 });

    const items = expectArray(assignmentObject.items, `${assignmentPath}.items`);
    if (!items.length) {
      throw new Error(`${assignmentPath}.items must contain at least one assignment item`);
    }

    for (const [itemIndex, item] of items.entries()) {
      const itemPath = `${assignmentPath}.items[${itemIndex}]`;
      const itemObject = expectObject(item, itemPath);
      const regionKey = expectString(itemObject.regionKey, `${itemPath}.regionKey`);
      if (!regionKeys.has(regionKey)) {
        throw new Error(`${itemPath}.regionKey must reference an existing region`);
      }
      expectString(itemObject.title, `${itemPath}.title`);
      expectEnum(itemObject.itemType, `${itemPath}.itemType`, ITEM_TYPES);
    }
  }

  return {
    pages: pages.length,
    regions: regionCount,
    assets: assetCount,
    assignments: assignments.length,
  };
}

function expectObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  return value;
}

function expectArray(value, label) {
  if (!Array.isArray(value)) {
    throw new Error(`${label} must be an array`);
  }
  return value;
}

function expectString(value, label) {
  if (typeof value !== 'string' || !value.trim()) {
    throw new Error(`${label} must be a non-empty string`);
  }
  return value.trim();
}

function expectUniqueString(value, label, store) {
  const normalized = expectString(value, label);
  if (store.has(normalized)) {
    throw new Error(`${label} must be unique`);
  }
  store.add(normalized);
  return normalized;
}

function expectEnum(value, label, allowedValues) {
  const normalized = expectString(value, label);
  if (!allowedValues.has(normalized)) {
    throw new Error(`${label} must be one of: ${Array.from(allowedValues).join(', ')}`);
  }
  return normalized;
}

function expectInteger(value, label, constraints = {}) {
  if (!Number.isInteger(value)) {
    throw new Error(`${label} must be an integer`);
  }
  if (constraints.min != null && value < constraints.min) {
    throw new Error(`${label} must be >= ${constraints.min}`);
  }
  return value;
}

function expectNumber(value, label, constraints = {}) {
  if (typeof value !== 'number' || Number.isNaN(value)) {
    throw new Error(`${label} must be a number`);
  }
  if (constraints.minExclusive != null && value <= constraints.minExclusive) {
    throw new Error(`${label} must be > ${constraints.minExclusive}`);
  }
  if (constraints.maxInclusive != null && value > constraints.maxInclusive) {
    throw new Error(`${label} must be <= ${constraints.maxInclusive}`);
  }
  return value;
}

function expectBoxValue(value, label) {
  return expectNumber(value, label, { minExclusive: -0.000001, maxInclusive: 1 });
}

function expectPathPrefix(value, label, prefix) {
  const normalized = expectString(value, label);
  if (!normalized.startsWith(prefix)) {
    throw new Error(`${label} must start with ${prefix}`);
  }
  return normalized;
}

async function expectBundledAsset(value, label, cwd, expectedPrefix) {
  const reference = expectString(value, label);
  const rawPath = reference.startsWith('asset:') ? reference.slice('asset:'.length) : reference;
  if (!rawPath.startsWith(expectedPrefix)) {
    throw new Error(`${label} must point to ${expectedPrefix}`);
  }

  const filePath = path.resolve(cwd, rawPath);
  try {
    const stat = await fs.stat(filePath);
    if (!stat.isFile() || stat.size <= 0) {
      throw new Error(`${label} must point to a non-empty file`);
    }
  } catch (error) {
    throw new Error(`${label} file does not exist: ${rawPath}`);
  }
}

await main();
