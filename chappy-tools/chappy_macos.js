#!/usr/bin/env osascript -l JavaScript
// Native macOS dialog UI. It talks only to the adjacent Python backend.

ObjC.import('Foundation');
const app = Application.currentApplication();
app.includeStandardAdditions = true;

function value(name) {
  const item = $.NSProcessInfo.processInfo.environment.objectForKey(name);
  return item ? ObjC.unwrap(item) : '';
}

function quote(text) {
  return "'" + String(text).replace(/'/g, "'\\''") + "'";
}

function encoded(value) {
  const text = $.NSString.alloc.initWithUTF8String(JSON.stringify(value));
  return ObjC.unwrap(text.dataUsingEncoding($.NSUTF8StringEncoding).base64EncodedStringWithOptions(0));
}

function trim(text, length) {
  return text.length > length ? text.slice(0, length - 1) + '…' : text;
}

function run() {
  const folder = value('CHAPPY_APP_DIR');
  const dashboard = value('CHAPPY_DASHBOARD_PATH');
  const history = [];
  let voiceEnabled = true;
  const transcript = ['Chappy: Hello. I run locally and can search only the approved project documents. I speak replies by default. Use FluidVoice or macOS Dictation in the text field for voice input.'];
  while (true) {
    try {
      const result = app.displayDialog(
        transcript.slice(-6).join('\n\n'),
        {withTitle: 'Chappy', defaultAnswer: '', buttons: ['Quit', 'Dashboard', 'Send'], defaultButton: 'Send', cancelButton: 'Quit'}
      );
      if (result.buttonReturned === 'Dashboard') {
        if (dashboard) {
          app.doShellScript('/usr/bin/open ' + quote(dashboard));
          transcript.push('Chappy: Opened the local dashboard.');
        } else {
          transcript.push('Chappy: I could not find the local dashboard file.');
        }
        continue;
      }
      const prompt = result.textReturned.trim();
      if (!prompt) continue;
      if (prompt.toLowerCase() === '/voice off' || prompt.toLowerCase() === '/voice on') {
        voiceEnabled = prompt.toLowerCase() === '/voice on';
        transcript.push('Chappy: Spoken replies are ' + (voiceEnabled ? 'on.' : 'off.'));
        continue;
      }
      transcript.push('You: ' + trim(prompt, 600));
      const command = '/usr/bin/python3 ' + quote(folder + '/chappy_backend.py') + ' ' + quote(encoded({prompt: prompt, history: history}));
      const raw = app.doShellScript(command);
      const response = JSON.parse(raw);
      const answer = response.error ? response.error : response.reply;
      transcript.push('Chappy: ' + trim(answer, 1200));
      if (voiceEnabled && !response.error) {
        app.doShellScript('(/usr/bin/say ' + quote(answer) + ' >/dev/null 2>&1 &)');
      }
      if (!response.error) {
        history.push({role: 'user', content: prompt}, {role: 'assistant', content: answer});
        while (history.length > 10) history.shift();
      }
    } catch (error) {
      if (error && error.errorNumber === -128) return;
      transcript.push('Chappy: ' + trim(String(error), 600));
    }
  }
}

run();
