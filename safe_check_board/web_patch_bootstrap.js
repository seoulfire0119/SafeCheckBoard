// deploy.bat [2/3] 단계: build/web/flutter_bootstrap.js 의 로더 호출을 바꾼다.
//  - 서비스 워커 설정을 빼서 비활성화 (예전 deploy.bat 의 한 줄 패치와 같은 목적)
//  - 앱을 화면 전체가 아니라 #flutter_host 안에 띄운다 → 위쪽 AI사다리(네임카드) 링크 바가 가려지지 않음
const fs = require('fs');
const f = 'build/web/flutter_bootstrap.js';
let c = fs.readFileSync(f, 'utf8');
const call = "_flutter.loader.load({onEntrypointLoaded:async function(e){var h=document.getElementById('flutter_host');var a=await e.initializeEngine(h?{hostElement:h}:{});await a.runApp();}});";
const re = /_flutter\.loader\.load\((\{[\s\S]*?\})?\);/;
//  - main.dart.js 에 ?v= 를 붙인다 → 휴대폰에 1년 캐시된 옛 main.dart.js 대신 새 파일을 받음 (web/index.html 의 ?v= 와 같은 값)
const mainJs = '"mainJsPath":"main.dart.js?v=20261011"';
if (!c.includes(mainJs)) c = c.replace(/"mainJsPath":"main\.dart\.js[^"]*"/, mainJs);
if (!c.includes("getElementById('flutter_host')")) {
  if (!re.test(c)) { console.error('flutter_bootstrap.js 에서 _flutter.loader.load(...) 를 찾지 못함'); process.exit(1); }
  c = c.replace(re, call);
}
fs.writeFileSync(f, c);
console.log('완료');
