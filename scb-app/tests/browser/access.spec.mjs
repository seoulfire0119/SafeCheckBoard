import { test, expect } from '@playwright/test';

async function identity(page, dept) {
  await page.getByPlaceholder('예) 마포소방서 현장지휘팀').fill(dept);
  await page.getByPlaceholder('예) 상황관리').fill('상황관리');
  await page.getByRole('button', { name: '확인', exact: true }).click();
}

test('new scene, viewer join, permission grant, live status and lock', async ({ browser, page }) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto('/');
  await page.getByRole('button', { name: '새 세션 시작', exact: true }).click();
  await identity(page, '지휘팀');
  await page.getByPlaceholder('예) 101동').fill('검증 건물');
  await page.getByLabel('시작 층', { exact: true }).fill('1');
  await page.getByLabel('끝 층', { exact: true }).fill('2');
  await page.getByLabel('층당 세대수', { exact: true }).fill('2');
  await page.getByRole('button', { name: '현장 보드 시작', exact: true }).click();
  await expect(page.getByRole('button', { name: '권한 관리', exact: true })).toBeVisible();
  const code = await page.locator('.code-tag').textContent();
  await expect(page.locator('.save-indicator')).toContainText('서버 저장 완료');
  expect((await page.locator('.safety-strip').boundingBox()).height).toBeLessThan(100);
  await expect(page.locator('.ai-ladder-bar')).toBeHidden();

  const context = await browser.newContext({ viewport: { width: 1024, height: 768 } });
  const viewer = await context.newPage();
  viewer.on('pageerror', (e) => errors.push(e.message));
  await viewer.goto(`/?s=${code}`);
  await identity(viewer, '안전센터');
  await expect(viewer.locator('.read-only-notice')).toContainText('열람 중');
  await page.getByRole('button', { name: '권한 관리', exact: true }).click();
  await expect(page.locator('.access-list select')).toHaveCount(1);
  await page.locator('.access-list select').selectOption('editor');
  await page.getByRole('button', { name: '닫기', exact: true }).click();
  await expect(viewer.locator('.read-only-notice')).toHaveCount(0);

  await page.locator('.ucell').first().click();
  await page.getByRole('button', { name: '확인완료', exact: true }).click();
  await expect(viewer.locator('.ucell').first()).toHaveClass(/st-confirmed/);
  await expect(page.locator('.save-indicator')).toContainText('서버 저장 완료');
  await page.screenshot({ path: 'test-results/board-desktop.png', fullPage: true });
  await viewer.screenshot({ path: 'test-results/board-tablet.png', fullPage: true });
  await viewer.setViewportSize({ width: 390, height: 844 });
  await viewer.screenshot({ path: 'test-results/board-phone.png', fullPage: true });

  await page.getByRole('button', { name: '권한 관리', exact: true }).click();
  page.once('dialog', (dialog) => dialog.accept());
  await page.getByRole('button', { name: '현장 종료 · 읽기 전용으로 잠금', exact: true }).click();
  await expect(viewer.locator('.read-only-notice')).toContainText('종료');
  await page.getByRole('button', { name: '닫기', exact: true }).click();
  await page.getByRole('button', { name: '보고서', exact: true }).click();
  await page.getByRole('button', { name: '유관기관 활동', exact: true }).click();
  await expect(page.getByRole('heading', { name: /유관기관/ })).toBeVisible();
  await context.close();
  expect(errors).toEqual([]);
});

async function googleOwner(page) {
  await page.goto('/');
  await page.evaluate(async () => {
    const { auth } = await import('/src/firebase.ts');
    if (auth.emulatorConfig?.host !== '127.0.0.1' || auth.emulatorConfig?.port !== 9099) throw new Error('This test must only use the local auth emulator');
    const sdkUrl = performance.getEntriesByType('resource').find((entry) => entry.name.includes('/firebase_auth.js'))?.name;
    if (!sdkUrl) throw new Error('Auth SDK module not found');
    const { GoogleAuthProvider, signInWithCredential } = await import(sdkUrl);
    const encode = (v) => btoa(JSON.stringify(v)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
    const token = `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
      iss: 'https://accounts.google.com', aud: 'demo-safecheckboard', sub: 'google-owner-test',
      email: 'test-owner@example.com', email_verified: true,
      iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600,
    })}.`;
    await signInWithCredential(auth, GoogleAuthProvider.credential(token));
  });
  await expect(page.getByRole('button', { name: 'test-owner@example.com · 계정 변경' })).toBeVisible();
}

test('Google owner keeps management access from another PC', async ({ browser, page }) => {
  await googleOwner(page);
  await page.getByRole('button', { name: '새 세션 시작', exact: true }).click();
  await identity(page, '관리자');
  await page.getByPlaceholder('예) 101동').fill('계정 복구 검증');
  await page.getByLabel('시작 층', { exact: true }).fill('1');
  await page.getByLabel('끝 층', { exact: true }).fill('1');
  await page.getByLabel('층당 세대수', { exact: true }).fill('1');
  await page.getByRole('button', { name: '현장 보드 시작', exact: true }).click();
  await expect(page.getByRole('button', { name: '권한 관리', exact: true })).toBeVisible();
  const code = await page.locator('.code-tag').textContent();
  const context = await browser.newContext();
  const otherPC = await context.newPage();
  await googleOwner(otherPC);
  await otherPC.goto(`/?s=${code}`);
  await identity(otherPC, '다른 PC 관리자');
  await expect(otherPC.getByRole('button', { name: '권한 관리', exact: true })).toBeVisible();
  await context.close();
});
