// フラッシュメッセージ表示
function showFlash(message, type = 'success') {
  const flash = document.getElementById('flash');
  if (!flash) return;
  flash.textContent = message;
  flash.className = `flash ${type} show`;
  setTimeout(() => flash.classList.remove('show'), 3000);
}

// エラー表示
function showError(inputId, errorId) {
  document.getElementById(inputId).classList.add('input-error');
  document.getElementById(errorId).classList.add('show');
}

function clearError(inputId, errorId) {
  document.getElementById(inputId).classList.remove('input-error');
  document.getElementById(errorId).classList.remove('show');
}

// ログイン
function handleLogin() {
  const email = document.getElementById('email').value.trim();
  const password = document.getElementById('password').value.trim();
  let valid = true;

  clearError('email', 'email-error');
  clearError('password', 'password-error');

  if (!email) { showError('email', 'email-error'); valid = false; }
  if (!password) { showError('password', 'password-error'); valid = false; }

  if (valid) location.href = 'boards.html';
}

// 新規登録
function handleSignup() {
  const name = document.getElementById('name').value.trim();
  const email = document.getElementById('email').value.trim();
  const password = document.getElementById('password').value.trim();
  let valid = true;

  clearError('name', 'name-error');
  clearError('email', 'email-error');
  clearError('password', 'password-error');

  if (!name) { showError('name', 'name-error'); valid = false; }
  if (!email) { showError('email', 'email-error'); valid = false; }
  if (!password || password.length < 6) { showError('password', 'password-error'); valid = false; }

  if (valid) location.href = 'boards.html';
}

// ボード作成モーダル
function openModal() {
  document.getElementById('modal').classList.add('show');
  document.getElementById('board-name').focus();
}

function closeModal() {
  document.getElementById('modal').classList.remove('show');
  document.getElementById('board-name').value = '';
  clearError('board-name', 'board-name-error');
}

function addBoard() {
  const name = document.getElementById('board-name').value.trim();
  clearError('board-name', 'board-name-error');

  if (!name) { showError('board-name', 'board-name-error'); return; }

  const colors = ['#0052cc', '#0065ff', '#00875a', '#de350b', '#ff8b00'];
  const color = colors[Math.floor(Math.random() * colors.length)];
  const card = document.createElement('div');
  card.className = 'board-card';
  card.style.background = color;
  card.textContent = name;
  card.onclick = () => location.href = 'board_detail.html';
  document.getElementById('boards-grid').appendChild(card);

  closeModal();
  showFlash(`「${name}」を作成しました`);
}

// カード追加モーダル
let currentListId = null;

function openCardModal(listId) {
  currentListId = listId;
  document.getElementById('card-modal').classList.add('show');
  document.getElementById('card-title').focus();
}

function closeCardModal() {
  document.getElementById('card-modal').classList.remove('show');
  document.getElementById('card-title').value = '';
  clearError('card-title', 'card-title-error');
  currentListId = null;
}

function addCard() {
  const title = document.getElementById('card-title').value.trim();
  clearError('card-title', 'card-title-error');

  if (!title) { showError('card-title', 'card-title-error'); return; }

  const card = document.createElement('div');
  card.className = 'card-item';
  card.innerHTML = `
    <span>${title}</span>
    <div class="card-actions">
      <button class="btn btn-danger btn-sm" onclick="event.stopPropagation(); deleteCard(this)">削除</button>
    </div>
  `;
  card.onclick = () => location.href = 'card_detail.html';
  document.getElementById(currentListId).appendChild(card);

  closeCardModal();
  showFlash(`「${title}」を追加しました`);
}

// リスト追加モーダル
function openListModal() {
  document.getElementById('list-modal').classList.add('show');
  document.getElementById('list-name').focus();
}

function closeListModal() {
  document.getElementById('list-modal').classList.remove('show');
  document.getElementById('list-name').value = '';
  clearError('list-name', 'list-name-error');
}

function addList() {
  const name = document.getElementById('list-name').value.trim();
  clearError('list-name', 'list-name-error');

  if (!name) { showError('list-name', 'list-name-error'); return; }

  const listId = 'list-' + Date.now();
  const col = document.createElement('div');
  col.className = 'list-column';
  col.innerHTML = `
    <div class="list-header">
      <h3>${name}</h3>
      <div class="list-actions">
        <button class="btn btn-secondary btn-sm">編集</button>
        <button class="btn btn-danger btn-sm" onclick="deleteList(this)">削除</button>
      </div>
    </div>
    <div class="cards-list" id="${listId}"></div>
    <button class="btn-add-card" onclick="openCardModal('${listId}')">+ カードを追加</button>
  `;

  const addBtn = document.querySelector('.btn-add-list');
  addBtn.parentNode.insertBefore(col, addBtn);

  enableSortable(listId);
  closeListModal();
  showFlash(`「${name}」リストを追加しました`);
}

// 削除
function deleteCard(btn) {
  if (!confirm('このカードを削除しますか？')) return;
  btn.closest('.card-item').remove();
  showFlash('カードを削除しました');
}

function deleteList(btn) {
  if (!confirm('このリストを削除しますか？')) return;
  btn.closest('.list-column').remove();
  showFlash('リストを削除しました');
}

function confirmDelete() {
  if (!confirm('このボードを削除しますか？')) return;
  location.href = 'boards.html';
}

// カード保存
function saveCard() {
  const title = document.getElementById('card-title').value.trim();
  const dueDate = document.getElementById('card-due-date').value;

  clearError('card-title', 'title-error');
  clearError('card-due-date', 'date-error');

  if (!title) { showError('card-title', 'title-error'); return; }

  if (dueDate) {
    const today = new Date().toISOString().split('T')[0];
    if (dueDate < today) { showError('card-due-date', 'date-error'); return; }
  }

  showFlash('カードを保存しました');
  setTimeout(() => location.href = 'board_detail.html', 1000);
}

// ドラッグ&ドロップ（SortableJS）
const sortableInstances = {};

function enableSortable(listId) {
  const el = document.getElementById(listId);
  if (el && typeof Sortable !== 'undefined') {
    sortableInstances[listId] = Sortable.create(el, {
      group: 'cards',
      animation: 150,
      ghostClass: 'sortable-ghost',
      disabled: false,
    });
  }
}

// 並び替え
let currentSort = 'free';

function sortCards(mode) {
  currentSort = mode;

  // ボタンのアクティブ状態を更新
  ['sort-priority', 'sort-due', 'sort-free'].forEach(id => {
    const btn = document.getElementById(id);
    if (btn) btn.classList.remove('active');
  });
  const activeId = mode === 'priority' ? 'sort-priority' : mode === 'due_date' ? 'sort-due' : 'sort-free';
  const activeBtn = document.getElementById(activeId);
  if (activeBtn) activeBtn.classList.add('active');

  if (mode === 'free') {
    // フリーモード: ドラッグ有効のままにするだけ
    showFlash('フリー並び替えモードです。ドラッグで自由に並び替えできます');
    return;
  }

  // 全リストのカードを並び替え
  document.querySelectorAll('.cards-list').forEach(list => {
    const cards = Array.from(list.querySelectorAll('.card-item'));
    cards.sort((a, b) => {
      if (mode === 'priority') {
        return (parseInt(b.dataset.priority) || 0) - (parseInt(a.dataset.priority) || 0);
      } else if (mode === 'due_date') {
        const da = a.dataset.due || '9999-99-99';
        const db = b.dataset.due || '9999-99-99';
        return da.localeCompare(db);
      }
      return 0;
    });
    cards.forEach(card => list.appendChild(card));
  });

  const label = mode === 'priority' ? '優先度順' : '期限順';
  showFlash(`${label}に並び替えました。ドラッグで自由に並び替えもできます`);
}

// ページ読み込み時にSortable初期化
document.addEventListener('DOMContentLoaded', () => {
  ['list-1', 'list-2', 'list-3'].forEach(enableSortable);
  // フリーボタンをデフォルトでアクティブに
  const freeBtn = document.getElementById('sort-free');
  if (freeBtn) freeBtn.classList.add('active');
});
