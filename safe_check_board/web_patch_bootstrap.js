// deploy.bat [2/3] 단계: build/web/flutter_bootstrap.js 의 로더 호출을 바꾼다.
//  - 서비스 워커 설정을 빼서 비활성화 (예전 deploy.bat 의 한 줄 패치와 같은 목적)
//  - 앱을 화면 전체가 아니라 #flutter_host 안에 띄운다 → 위쪽 AI사다리(네임카드) 링크 바가 가려지지 않음
const fs = require('fs');
const f = 'build/web/flutter_bootstrap.js';
let c = fs.readFileSync(f, 'utf8');
const call = "_flutter.loader.load({onEntrypointLoaded:async function(e){var h=document.getElementById('flutter_host');var a=await e.initializeEngine(h?{hostElement:h}:{});await a.runApp();}});";
const re = /_flutter\.loader\.load\((\{[\s\S]*?\})?\);/;
if (c.includes("getElementById('flutter_host')")) { console.log('이미 적용됨'); process.exit(0); }
if (!re.test(c)) { console.error('flutter_bootstrap.js 에서 _flutter.loader.load(...) 를 찾지 못함'); process.exit(1); }
c = c.replace(re, call);
fs.writeFileSync(f, c);
console.log('완료');
