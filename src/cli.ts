#!/usr/bin/env node

import { Command } from '@commander-js/extra-typings';
import chalk from 'chalk';
import fs from 'fs-extra';
import ora from 'ora';
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';
import {
  displayProjectBanner,
  displaySuccess,
  displayError,
  displayInfo,
  displayStep,
  isInteractive,
  selectAIAssistant,
  selectScriptType,
  selectBashScriptType
} from './utils/interactive.js';
import { executeBashScript } from './utils/bash-runner.js';

// 读取 package.json 版本号
const require = createRequire(import.meta.url);
const { version } = require('../package.json');
import { parseCommandTemplate } from './utils/yaml-parser.js';
import { AIConfig } from './types/index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// AI 平台配置 - 所有支持的平台
const AI_CONFIGS: AIConfig[] = [
  { name: 'claude', dir: '.claude', commandsDir: 'commands', displayName: 'Claude Code' },
  { name: 'cursor', dir: '.cursor', commandsDir: 'commands', displayName: 'Cursor' },
  { name: 'gemini', dir: '.gemini', commandsDir: 'commands', displayName: 'Gemini CLI' },
  { name: 'windsurf', dir: '.windsurf', commandsDir: 'workflows', displayName: 'Windsurf' },
  { name: 'roocode', dir: '.roo', commandsDir: 'commands', displayName: 'Roo Code' },
  { name: 'copilot', dir: '.github', commandsDir: 'prompts', displayName: 'GitHub Copilot' },
  { name: 'qwen', dir: '.qwen', commandsDir: 'commands', displayName: 'Qwen Code' },
  { name: 'opencode', dir: '.opencode', commandsDir: 'command', displayName: 'OpenCode' },
  { name: 'codex', dir: '.codex', commandsDir: 'prompts', displayName: 'Codex CLI' },
  { name: 'kilocode', dir: '.kilocode', commandsDir: 'workflows', displayName: 'Kilo Code' },
  { name: 'auggie', dir: '.augment', commandsDir: 'commands', displayName: 'Auggie CLI' },
  { name: 'codebuddy', dir: '.codebuddy', commandsDir: 'commands', displayName: 'CodeBuddy' },
  { name: 'q', dir: '.amazonq', commandsDir: 'prompts', displayName: 'Amazon Q Developer' }
];

const program = new Command();

// Display banner
displayProjectBanner();

program
  .name('clipmate')
  .description(chalk.cyan('ClipMate - AI 驱动的视频剪辑工具'))
  .version(version);

// /init - 初始化项目(支持13个AI助手)
program
  .command('init')
  .argument('[name]', '项目名称')
  .option('--here', '在当前目录初始化')
  .option('--ai <type>', '选择 AI 助手 (claude|cursor|gemini|windsurf|roocode|copilot|qwen|opencode|codex|kilocode|auggie|codebuddy|q)')
  .description('初始化ClipMate项目(生成AI配置)')
  .action(async (name, options) => {
    // 交互式选择
    const shouldShowInteractive = isInteractive() && !options.ai;

    let selectedAI = 'claude';
    let selectedScriptType = 'sh';

    if (shouldShowInteractive) {
      // 显示欢迎横幅
      displayProjectBanner();

      // [1/2] 选择 AI 助手
      displayStep(1, 2, '选择 AI 助手');
      selectedAI = await selectAIAssistant(AI_CONFIGS);
      console.log('');

      // [2/2] 选择脚本类型
      displayStep(2, 2, '选择脚本类型');
      selectedScriptType = await selectBashScriptType();
      console.log('');
    } else if (options.ai) {
      selectedAI = options.ai;
    }

    const spinner = ora('正在初始化ClipMate项目...').start();

    try {
      // 确定项目路径
      let projectPath: string;
      if (options.here) {
        projectPath = process.cwd();
        name = path.basename(projectPath);
      } else {
        if (!name) {
          spinner.fail('请提供项目名称或使用 --here 参数');
          process.exit(1);
        }
        projectPath = path.join(process.cwd(), name);
        if (await fs.pathExists(projectPath)) {
          spinner.fail(`项目目录 "${name}" 已存在`);
          process.exit(1);
        }
        await fs.ensureDir(projectPath);
      }

      // 获取选中的AI配置
      const aiConfig = AI_CONFIGS.find(c => c.name === selectedAI);
      if (!aiConfig) {
        spinner.fail(`不支持的AI助手: ${selectedAI}`);
        process.exit(1);
      }

      // 创建基础项目结构
      const dirs = [
        '.clipmate',
        `${aiConfig.dir}/${aiConfig.commandsDir}`,
        'videos',
        'clips',
        'subtitles',
        'exports'
      ];

      for (const dir of dirs) {
        await fs.ensureDir(path.join(projectPath, dir));
      }

      // 创建项目配置文件 (用于标识项目根目录)
      const config = {
        name: name,
        type: 'clipmate-project',
        ai: selectedAI,
        scriptType: selectedScriptType,
        created: new Date().toISOString(),
        version: '0.1.0'
      };
      await fs.writeJson(path.join(projectPath, '.clipmate', 'config.json'), config, { spaces: 2 });

      // 创建阿里云配置模板
      const aliyunConfig = {
        access_key_id: "",
        access_key_secret: "",
        asr: {
          app_key: "",
          model: "generic",
          format: "mp3",
          sample_rate: 16000,
          enable_punctuation: true,
          enable_inverse_text_normalization: true,
          enable_words: true,
          max_single_segment_time: 15000
        }
      };
      await fs.writeJson(path.join(projectPath, '.clipmate', 'aliyun.json'), aliyunConfig, { spaces: 2 });

      // 从npm包复制模板和脚本到项目
      const packageRoot = path.resolve(__dirname, '..');

      // 根据选择的脚本类型复制对应脚本
      const scriptsSubDir = selectedScriptType === 'ps' ? 'powershell' : 'bash';
      const scriptsSource = path.join(packageRoot, 'scripts', scriptsSubDir);
      const scriptsTarget = path.join(projectPath, 'scripts', scriptsSubDir);

      if (await fs.pathExists(scriptsSource)) {
        await fs.copy(scriptsSource, scriptsTarget);

        // 设置bash脚本执行权限
        if (selectedScriptType === 'sh') {
          const bashFiles = await fs.readdir(scriptsTarget);
          for (const file of bashFiles) {
            if (file.endsWith('.sh')) {
              const filePath = path.join(scriptsTarget, file);
              await fs.chmod(filePath, 0o755);
            }
          }
        }
      }

      // 复制Python脚本
      const pythonSource = path.join(packageRoot, 'scripts', 'python');
      const pythonTarget = path.join(projectPath, 'scripts', 'python');
      if (await fs.pathExists(pythonSource)) {
        await fs.copy(pythonSource, pythonTarget);
      }

      // 复制templates到项目
      const templatesSource = path.join(packageRoot, 'templates');
      const templatesTarget = path.join(projectPath, 'templates');
      if (await fs.pathExists(templatesSource)) {
        await fs.copy(templatesSource, templatesTarget);
      }

      // 生成AI配置文件（直接复制模板文件）
      const commandFiles = await fs.readdir(path.join(packageRoot, 'templates', 'commands'));

      for (const file of commandFiles) {
        if (file.endsWith('.md')) {
          // 直接复制模板文件
          const sourcePath = path.join(packageRoot, 'templates', 'commands', file);
          const targetPath = path.join(projectPath, aiConfig.dir, aiConfig.commandsDir, file);
          await fs.copy(sourcePath, targetPath);
        }
      }

      // 创建README
      const readme = `# ${name}

使用 ClipMate 创建的视频剪辑项目

## 配置

- **AI 助手**: ${aiConfig.displayName}
- **脚本类型**: ${selectedScriptType === 'sh' ? 'POSIX Shell (macOS/Linux)' : 'PowerShell (Windows)'}

## 视频剪辑流程

使用 Slash Commands 完成视频剪辑：

\`\`\`bash
/import       # 1. 导入视频素材
/detect       # 2. AI 智能检测(静音/重复/场景)
/cut          # 3. 智能剪辑(删除/加速)
/merge        # 4. 合并片段
/transcribe   # 5. 语音识别生成字幕(阿里云)
/subtitle     # 6. 字幕处理和烧录
/export       # 7. 导出成品
\`\`\`

## 项目结构

- \`videos/\` - 原始视频素材
- \`clips/\` - 剪辑片段和检测报告
- \`subtitles/\` - 字幕文件
- \`exports/\` - 导出的成品视频
- \`scripts/${scriptsSubDir}/\` - ${selectedScriptType === 'sh' ? 'Bash' : 'PowerShell'}脚本
- \`scripts/python/\` - Python 视频处理脚本
- \`templates/\` - AI提示词模板
- \`.clipmate/\` - 项目配置
- \`${aiConfig.dir}/\` - ${aiConfig.displayName}配置

## 配置阿里云 API

编辑 \`.clipmate/aliyun.json\` 文件，填入你的阿里云 API 密钥：

\`\`\`json
{
  "access_key_id": "your_access_key_id",
  "access_key_secret": "your_access_key_secret",
  "asr": {
    "app_key": "your_asr_app_key"
  }
}
\`\`\`

获取密钥: https://ram.console.aliyun.com/

## 文档

查看 [ClipMate文档](https://github.com/wordflowlab/clipmate)
`;

      await fs.writeFile(path.join(projectPath, 'README.md'), readme);

      spinner.succeed(`项目 "${name}" 初始化成功!`);

      console.log('');
      displayInfo('下一步:');
      if (!options.here) {
        console.log(`  • cd ${name}`);
      }
      console.log(`  • 将视频文件放入 videos/ 目录`);
      console.log(`  • 运行 /import 导入视频`);
      console.log(`  • 运行 /detect 开始智能检测`);
      console.log(`  • 配置阿里云密钥(用于字幕生成)`);

    } catch (error) {
      spinner.fail('初始化项目失败');
      console.error(error);
      process.exit(1);
    }
  });

// /import - 导入视频
program
  .command('import')
  .description('导入视频素材并分析')
  .argument('[video]', '视频文件路径')
  .action(async (video?: string) => {
    try {
      const args = video ? [video] : [];
      const result = await executeBashScript('import', args);

      if (result.status === 'success') {
        displaySuccess(`项目: ${result.project_name}`);

        const templatePath = 'templates/commands/import.md';
        if (await fs.pathExists(templatePath)) {
          const { metadata, content } = await parseCommandTemplate(templatePath);
          console.log('\n' + chalk.dim('─'.repeat(50)));
          console.log(content);
          console.log(chalk.dim('─'.repeat(50)) + '\n');

          console.log(chalk.dim('## 脚本输出信息\n'));
          console.log('```json');
          console.log(JSON.stringify(result, null, 2));
          console.log('```');
        }
      } else {
        displayError(result.message || '发生未知错误');
        process.exit(1);
      }
    } catch (error) {
      displayError(error instanceof Error ? error.message : String(error));
      process.exit(1);
    }
  });

// /detect - 视频智能检测
program
  .command('detect')
  .description('AI 智能检测(静音/重复/场景)')
  .option('--preset <type>', '检测预设(teaching|meeting|vlog|short)')
  .action(async (options) => {
    try {
      const args = options.preset ? ['--preset', options.preset] : [];
      const result = await executeBashScript('detect', args);

      if (result.status === 'success') {
        displaySuccess(`项目: ${result.project_name}`);

        const templatePath = 'templates/commands/detect.md';
        if (await fs.pathExists(templatePath)) {
          const { metadata, content } = await parseCommandTemplate(templatePath);
          console.log('\n' + chalk.dim('─'.repeat(50)));
          console.log(content);
          console.log(chalk.dim('─'.repeat(50)) + '\n');

          console.log(chalk.dim('## 脚本输出信息\n'));
          console.log('```json');
          console.log(JSON.stringify(result, null, 2));
          console.log('```');
        }
      } else {
        displayError(result.message || '发生未知错误');
        process.exit(1);
      }
    } catch (error) {
      displayError(error instanceof Error ? error.message : String(error));
      process.exit(1);
    }
  });

// /cut - 智能剪辑
program
  .command('cut')
  .description('智能剪辑(删除/加速)')
  .option('--auto', '自动剪辑模式')
  .option('--interactive', '交互式确认')
  .action(async (options) => {
    try {
      const args = [];
      if (options.auto) args.push('--auto');
      if (options.interactive) args.push('--interactive');

      const result = await executeBashScript('cut', args);

      if (result.status === 'success') {
        displaySuccess(`项目: ${result.project_name}`);

        const templatePath = 'templates/commands/cut.md';
        if (await fs.pathExists(templatePath)) {
          const { metadata, content } = await parseCommandTemplate(templatePath);
          console.log('\n' + chalk.dim('─'.repeat(50)));
          console.log(content);
          console.log(chalk.dim('─'.repeat(50)) + '\n');

          console.log(chalk.dim('## 脚本输出信息\n'));
          console.log('```json');
          console.log(JSON.stringify(result, null, 2));
          console.log('```');
        }
      } else {
        displayError(result.message || '发生未知错误');
        process.exit(1);
      }
    } catch (error) {
      displayError(error instanceof Error ? error.message : String(error));
      process.exit(1);
    }
  });

// /merge - 合并片段
program
  .command('merge')
  .description('合并剪辑片段')
  .action(async () => {
    try {
      const result = await executeBashScript('merge', []);

      if (result.status === 'success') {
        displaySuccess(`项目: ${result.project_name}`);

        const templatePath = 'templates/commands/merge.md';
        if (await fs.pathExists(templatePath)) {
          const { metadata, content } = await parseCommandTemplate(templatePath);
          console.log('\n' + chalk.dim('─'.repeat(50)));
          console.log(content);
          console.log(chalk.dim('─'.repeat(50)) + '\n');

          console.log(chalk.dim('## 脚本输出信息\n'));
          console.log('```json');
          console.log(JSON.stringify(result, null, 2));
          console.log('```');
        }
      } else {
        displayError(result.message || '发生未知错误');
        process.exit(1);
      }
    } catch (error) {
      displayError(error instanceof Error ? error.message : String(error));
      process.exit(1);
    }
  });

// /transcribe - 语音识别
program
  .command('transcribe')
  .description('语音识别生成字幕(阿里云)')
  .option('--model <type>', '识别模型(generic|education|meeting|entertainment)')
  .option('--lang <lang>', '语言(zh|en)', 'zh')
  .action(async (options) => {
    try {
      const args = [];
      if (options.model) args.push('--model', options.model);
      if (options.lang) args.push('--lang', options.lang);

      const result = await executeBashScript('transcribe', args);

      if (result.status === 'success') {
        displaySuccess(`项目: ${result.project_name}`);

        const templatePath = 'templates/commands/transcribe.md';
        if (await fs.pathExists(templatePath)) {
          const { metadata, content } = await parseCommandTemplate(templatePath);
          console.log('\n' + chalk.dim('─'.repeat(50)));
          console.log(content);
          console.log(chalk.dim('─'.repeat(50)) + '\n');

          console.log(chalk.dim('## 脚本输出信息\n'));
          console.log('```json');
          console.log(JSON.stringify(result, null, 2));
          console.log('```');
        }
      } else {
        displayError(result.message || '发生未知错误');
        process.exit(1);
      }
    } catch (error) {
      displayError(error instanceof Error ? error.message : String(error));
      process.exit(1);
    }
  });

// /subtitle - 字幕处理
program
  .command('subtitle')
  .description('字幕处理和烧录')
  .option('--burn', '烧录字幕到视频')
  .option('--style <style>', '字幕样式')
  .action(async (options) => {
    try {
      const args = [];
      if (options.burn) args.push('--burn');
      if (options.style) args.push('--style', options.style);

      const result = await executeBashScript('subtitle', args);

      if (result.status === 'success') {
        displaySuccess(`项目: ${result.project_name}`);

        const templatePath = 'templates/commands/subtitle.md';
        if (await fs.pathExists(templatePath)) {
          const { metadata, content } = await parseCommandTemplate(templatePath);
          console.log('\n' + chalk.dim('─'.repeat(50)));
          console.log(content);
          console.log(chalk.dim('─'.repeat(50)) + '\n');

          console.log(chalk.dim('## 脚本输出信息\n'));
          console.log('```json');
          console.log(JSON.stringify(result, null, 2));
          console.log('```');
        }
      } else {
        displayError(result.message || '发生未知错误');
        process.exit(1);
      }
    } catch (error) {
      displayError(error instanceof Error ? error.message : String(error));
      process.exit(1);
    }
  });

// /export - 导出视频
program
  .command('export')
  .description('导出成品视频')
  .option('--preset <preset>', '导出预设(youtube|bilibili|douyin|xiaohongshu)')
  .option('--quality <quality>', '视频质量(high|medium|low)', 'high')
  .action(async (options) => {
    try {
      const args = [];
      if (options.preset) args.push('--preset', options.preset);
      if (options.quality) args.push('--quality', options.quality);

      const result = await executeBashScript('export', args);

      if (result.status === 'success') {
        displaySuccess(`项目: ${result.project_name}`);

        const templatePath = 'templates/commands/export.md';
        if (await fs.pathExists(templatePath)) {
          const { metadata, content } = await parseCommandTemplate(templatePath);
          console.log('\n' + chalk.dim('─'.repeat(50)));
          console.log(content);
          console.log(chalk.dim('─'.repeat(50)) + '\n');

          console.log(chalk.dim('## 脚本输出信息\n'));
          console.log('```json');
          console.log(JSON.stringify(result, null, 2));
          console.log('```');
        }
      } else {
        displayError(result.message || '发生未知错误');
        process.exit(1);
      }
    } catch (error) {
      displayError(error instanceof Error ? error.message : String(error));
      process.exit(1);
    }
  });

// setup-python - 设置 Python 虚拟环境
program
  .command('setup-python')
  .description('设置 Python 虚拟环境和依赖')
  .action(async () => {
    const { execSync } = await import('child_process');

    try {
      displayInfo('正在设置 Python 虚拟环境...\n');

      // 检查 Python 版本
      displayInfo('检查 Python 版本...');
      try {
        const pythonVersion = execSync('python3 --version', { encoding: 'utf-8' });
        console.log(chalk.green(`✓ ${pythonVersion.trim()}`));
      } catch {
        displayError('未找到 python3，请先安装 Python 3.8+');
        process.exit(1);
      }

      const cwd = process.cwd();
      const venvPath = path.join(cwd, 'venv');
      const reqPath = path.join(cwd, 'requirements.txt');

      // 创建 requirements.txt（如果不存在）
      if (!await fs.pathExists(reqPath)) {
        displayInfo('创建 requirements.txt...');
        const requirementsContent = `opencv-python>=4.8.0
numpy>=1.24.0
pydub>=0.25.1
`;
        await fs.writeFile(reqPath, requirementsContent);
        console.log(chalk.green('✓ requirements.txt 创建成功'));
      } else {
        console.log(chalk.dim('requirements.txt 已存在'));
      }

      // 创建虚拟环境
      if (!await fs.pathExists(venvPath)) {
        displayInfo('创建虚拟环境...');
        execSync('python3 -m venv venv', {
          stdio: 'inherit',
          cwd
        });
        console.log(chalk.green('✓ 虚拟环境创建成功'));
      } else {
        console.log(chalk.dim('虚拟环境已存在'));
      }

      // 升级 pip
      displayInfo('升级 pip...');
      execSync('venv/bin/pip install --upgrade pip', {
        stdio: 'pipe',
        cwd
      });
      console.log(chalk.green('✓ pip 升级完成'));

      // 安装依赖
      displayInfo('安装 Python 依赖 (opencv-python, numpy, pydub)...');
      execSync('venv/bin/pip install -r requirements.txt', {
        stdio: 'inherit',
        cwd
      });

      displaySuccess('\n✅ Python 环境设置完成！');
      console.log('');
      console.log(chalk.cyan('📝 使用说明:'));
      console.log('   1. ClipMate 脚本会自动使用虚拟环境，无需手动激活');
      console.log('   2. 如需手动使用: source venv/bin/activate');
      console.log('   3. 退出虚拟环境: deactivate');
      console.log('');

    } catch (error) {
      displayError('Python 环境设置失败');
      if (error instanceof Error) {
        console.error(chalk.red(error.message));
      }
      process.exit(1);
    }
  });

program.parse();
