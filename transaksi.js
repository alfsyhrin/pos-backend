// Fetch transactions from API
async function fetchTransactions({ search = '', page = 1, limit = 20 } = {}) {
  const storeId = localStorage.getItem('store_id');
  const token = localStorage.getItem('token');
  if (!storeId || !token) return [];

  // Build query string
  const params = [];
  if (search) params.push(`search=${encodeURIComponent(search)}`);
  params.push(`page=${page}`);
  params.push(`limit=${limit}`);
  const query = params.length ? `?${params.join('&')}` : '';

  try {
    const url = `http://103.126.116.119:8001/api/stores/${storeId}/transactions${query}`;
    const res = await fetch(url, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`
      }
    });
    const data = await res.json();
    if (res.ok && data.success) {
      return data.data.items || [];
    } else {
      return [];
    }
  } catch (err) {
    return [];
  }
}

// Render transactions to the page
function renderTransactions(transactions) {
  const wrapper = document.querySelector('.card-transaksi-wrapper');
  if (!wrapper) return;

  wrapper.innerHTML = '';

  if (transactions.length === 0) {
    const card = document.createElement('div');
    card.className = 'card-transaksi';
    card.innerHTML = `
      <span class="material-symbols-outlined transaksi">receipt_long</span>
      <div class="info-transaksi">
        <div class="no-harga-wrapper">
          <p class="no-transaksi">Belum ada transaksi</p>
          <p class="harga-transaksi-utama">-</p>
        </div>
        <p class="tanggal-transaksi">-</p>
        <div class="jenis-totalitem-wrapper">
          <p class="jenis-transaksi"><span class="material-symbols-outlined">local_atm</span>-</p>
          <p class="total-item-transaksi">-</p>
        </div>
      </div>
      <div class="button-hapus-transaksi">
        <button class="btn-hapus-transaksi" style="visibility: hidden;"><span class="material-symbols-outlined">delete</span></button>
      </div>
    `;
    wrapper.appendChild(card);
    return;
  }

  transactions.forEach(trx => {
    const card = document.createElement('div');
    card.className = 'card-transaksi';
    card.style.position = 'relative';

    const createdAt = trx.createdAt ? new Date(trx.createdAt).toLocaleString('id-ID') : '-';
    const total = Number(trx.total || 0);
    const method = trx.method || 'Tunai';
    const itemCount = trx.items ? trx.items.length : 0;
    const idShort = trx.idShort || trx.idFull || trx.transaction_id || '-';

    card.innerHTML = `
      <input type="checkbox" class="trx-checkbox" data-id="${trx.transaction_id}" style="position:absolute;top:10px;left:10px;width:18px;height:18px;cursor:pointer;">
      
      <span class="material-symbols-outlined transaksi">receipt_long</span>
      <div class="info-transaksi">
        <div class="no-harga-wrapper">
          <p class="no-transaksi">#${idShort}</p>
          <p class="harga-transaksi-utama">Rp ${total.toLocaleString('id-ID')}</p>
        </div>
        <p class="tanggal-transaksi">${createdAt}</p>
        <div class="jenis-totalitem-wrapper">
          <p class="jenis-transaksi"><span class="material-symbols-outlined">local_atm</span>${method}</p>
          <p class="total-item-transaksi">${itemCount} item</p>
        </div>
      </div>
      <div class="button-hapus-transaksi">
        <button class="btn-hapus-transaksi" onclick="event.stopPropagation(); deleteTransaction('${trx.transaction_id}')">
          <span class="material-symbols-outlined">delete</span>
        </button>
      </div>
    `;

    card.addEventListener('click', (e) => {
      if (!e.target.closest('.trx-checkbox') && !e.target.closest('.btn-hapus-transaksi')) {
        viewTransactionDetail(trx.transaction_id);
      }
    });

    wrapper.appendChild(card);
  });

  setupBulkDelete();
}

// View transaction detail
function viewTransactionDetail(transactionId) {
  localStorage.setItem('selected_transaction_id', transactionId);
  window.location.href = 'detail-transaksi.html';
}

// Delete transaction
async function deleteTransaction(transactionId) {
  if (!transactionId) {
    alert('ID transaksi tidak valid!');
    return;
  }
  if (!confirm('Apakah Anda yakin ingin menghapus transaksi ini?')) return;

  const storeId = localStorage.getItem('store_id');
  const token = localStorage.getItem('token');
  if (!storeId || !token) {
    alert('Authentication error');
    return;
  }

  try {
    const res = await fetch(`http://103.126.116.119:8001/api/stores/${storeId}/transactions/${transactionId}`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`
      }
    });
    const data = await res.json();
    if (res.ok && data.success) {
      alert('Transaksi berhasil dihapus');
      loadTransactions(transaksiFilters);
    } else {
      alert('Gagal menghapus transaksi: ' + (data.message || 'Unknown error'));
    }
  } catch (err) {
    console.error('Error deleting transaction:', err);
    alert('Error menghapus transaksi');
  }
}

// Load and display transactions
async function loadTransactions(filters = {}) {
  const container = document.querySelector('.transactions-list') || document.querySelector('.card-transaksi-wrapper');
  if (!container) return;
  container.innerHTML = '<p>Memuat transaksi...</p>';

  const role = (localStorage.getItem('role') || '').toLowerCase();
  let storeId = localStorage.getItem('store_id');

  try {
    // Jika owner dan belum ada store_id, tampilkan modal
    if (role === 'owner' && !storeId) {
      const stores = await window.fetchStoresForOwner();
      if (stores && stores.length > 0) {
        storeId = await window.showStoreSelectionModal(stores);
        if (!storeId) {
          container.innerHTML = '<p>Pemilihan toko dibatalkan.</p>';
          return;
        }
        localStorage.setItem('store_id', storeId);
      } else {
        container.innerHTML = `<p style="color: #ff6b6b; padding: 20px; text-align: center;">⚠️ Anda belum memilih toko.</p>`;
        return;
      }
    }

    if (!storeId) {
      container.innerHTML = '<p>Store tidak ditemukan.</p>';
      return;
    }

    // Fetch transaksi dengan query params yang benar
    const transactions = await fetchTransactions({
      search: filters.search || '',
      page: filters.page || 1,
      limit: filters.limit || 20
    });

    if (!transactions || transactions.length === 0) {
      // Tampilkan card kosong
      const card = document.createElement('div');
      card.className = 'card-transaksi';
      card.innerHTML = `
        <span class="material-symbols-outlined transaksi">receipt_long</span>
        <div class="info-transaksi">
          <div class="no-harga-wrapper">
            <p class="no-transaksi">Belum ada transaksi</p>
            <p class="harga-transaksi-utama">-</p>
          </div>
          <p class="tanggal-transaksi">-</p>
          <div class="jenis-totalitem-wrapper">
            <p class="jenis-transaksi"><span class="material-symbols-outlined">local_atm</span>-</p>
            <p class="total-item-transaksi">-</p>
          </div>
        </div>
        <div class="button-hapus-transaksi">
          <button class="btn-hapus-transaksi" style="visibility: hidden;"><span class="material-symbols-outlined">delete</span></button>
        </div>
      `;
      container.innerHTML = '';
      container.appendChild(card);
      return;
    }

    renderTransactions(transactions);
    window.updateHeaderStoreName();
  } catch (err) {
    console.error('Error loading transactions:', err);
    container.innerHTML = `<p style="color:red;">Gagal memuat transaksi: ${err.message}</p>`;
  }
}

// Event listener untuk search
async function initTransaksi() {
  window.updateHeaderStoreName();
  loadTransactions(transaksiFilters);

  const searchInput = document.getElementById('search-transaksi');
  if (searchInput) {
    searchInput.addEventListener('input', () => {
      transaksiFilters.search = searchInput.value;
      transaksiFilters.page = 1;
      loadTransactions(transaksiFilters);
    });
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initTransaksi);
} else {
  initTransaksi();
}

window.initTransaksi = initTransaksi;

const transaksiFilters = {
  search: '',
  page: 1,
  limit: 20
};

// TAMBAH: Setup bulk delete
function setupBulkDelete() {
  const container = document.querySelector('.card-transaksi-wrapper');
  const header = document.querySelector('.bar-pencarian-kasir');
  
  // Buat toolbar bulk delete
  let toolbar = document.getElementById('bulk-delete-toolbar');
  if (!toolbar) {
    toolbar = document.createElement('div');
    toolbar.id = 'bulk-delete-toolbar';
    toolbar.style.cssText = `
      display: none;
      position: sticky;
      bottom: 0;
      left: 0;
      right: 0;
      padding: 12px 16px;
      background: #c41e3a;
      color: white;
      text-align: center;
      border-top: 1px solid #a01830;
      gap: 10px;
    `;
    toolbar.innerHTML = `
      <span id="bulk-count">0 dipilih</span>
      <button id="btn-delete-selected" style="padding:8px 16px;background:#fff;color:#c41e3a;border:none;border-radius:4px;font-weight:bold;cursor:pointer;">
        Hapus Terpilih
      </button>
      <button id="btn-delete-all" style="padding:8px 16px;background:#fff;color:#c41e3a;border:none;border-radius:4px;font-weight:bold;cursor:pointer;">
        Hapus Semua
      </button>
      <button id="btn-cancel-bulk" style="padding:8px 16px;background:transparent;color:#fff;border:1px solid #fff;border-radius:4px;cursor:pointer;">
        Batal
      </button>
    `;
    container.parentElement.insertBefore(toolbar, container);
  }

  // Event listener checkboxes
  document.querySelectorAll('.trx-checkbox').forEach(checkbox => {
    checkbox.addEventListener('change', updateBulkToolbar);
  });

  document.getElementById('btn-delete-selected').addEventListener('click', deleteBulkTransactions);
  document.getElementById('btn-delete-all').addEventListener('click', deleteAllTransactions);
  document.getElementById('btn-cancel-bulk').addEventListener('click', cancelBulkSelect);
}

function updateBulkToolbar() {
  const checkboxes = document.querySelectorAll('.trx-checkbox');
  const checked = Array.from(checkboxes).filter(c => c.checked).length;
  const total = checkboxes.length;
  const toolbar = document.getElementById('bulk-delete-toolbar');
  
  if (checked > 0) {
    toolbar.style.display = 'flex';
    toolbar.style.justifyContent = 'center';
    toolbar.style.alignItems = 'center';
    document.getElementById('bulk-count').textContent = `${checked} dari ${total} dipilih`;
  } else {
    toolbar.style.display = 'none';
  }
}

async function deleteBulkTransactions() {
  const checkboxes = Array.from(document.querySelectorAll('.trx-checkbox:checked'));
  if (checkboxes.length === 0) {
    alert('Pilih minimal 1 transaksi');
    return;
  }

  if (!confirm(`Hapus ${checkboxes.length} transaksi terpilih?`)) return;

  const storeId = localStorage.getItem('store_id');
  const token = localStorage.getItem('token');
  if (!storeId || !token) {
    alert('Authentication error');
    return;
  }

  let deleted = 0;
  for (const checkbox of checkboxes) {
    const txId = checkbox.dataset.id;
    try {
      const res = await fetch(`http://103.126.116.119:8001/api/stores/${storeId}/transactions/${txId}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` }
      });
      if (res.ok) deleted++;
    } catch (e) { /* skip */ }
  }

  alert(`${deleted} transaksi berhasil dihapus`);
  loadTransactions(transaksiFilters);
}

async function deleteAllTransactions() {
  if (!confirm('Hapus SEMUA transaksi? Ini tidak bisa dibatalkan!')) return;

  const storeId = localStorage.getItem('store_id');
  const token = localStorage.getItem('token');
  if (!storeId || !token) {
    alert('Authentication error');
    return;
  }

  // Fetch semua transaksi dulu
  const allTx = await fetchTransactions({ limit: 1000 });
  if (!allTx || allTx.length === 0) {
    alert('Tidak ada transaksi untuk dihapus');
    return;
  }

  let deleted = 0;
  for (const tx of allTx) {
    try {
      const res = await fetch(`http://103.126.116.119:8001/api/stores/${storeId}/transactions/${tx.transaction_id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` }
      });
    if (res.ok) deleted++;
    } catch (e) { /* skip */ }
  }

  alert(`${deleted} transaksi berhasil dihapus`);
  loadTransactions(transaksiFilters);
}

function cancelBulkSelect() {
  document.querySelectorAll('.trx-checkbox').forEach(c => c.checked = false);
  document.getElementById('bulk-delete-toolbar').style.display = 'none';
}

window.showStoreSelectionModal = function(stores = []) {
  return new Promise(resolve => {
    const modal = document.createElement('div');
    modal.className = 'store-select-modal';
    modal.style = 'position:fixed;inset:0;background:rgba(0,0,0,0.6);display:flex;align-items:center;justify-content:center;z-index:9999;';
    const box = document.createElement('div');
    box.style = 'background:#1b1b1b;padding:20px;border-radius:8px;max-width:600px;width:90%;color:#fff;';
    box.innerHTML = `<h3>Pilih toko untuk melihat transaksi</h3><div class="list-stores" style="margin-top:10px;"></div><div style="text-align:right;margin-top:12px;"><button class="cancel-store" style="margin-right:8px;">Batal</button></div>`;
    modal.appendChild(box);
    document.body.appendChild(modal);
    const listEl = box.querySelector('.list-stores');
    stores.forEach(s => {
      const btn = document.createElement('button');
      btn.textContent = `${s.id} — ${s.name || s.branch || s.store_name || '-'}`;
      btn.style = 'display:block;margin:6px 0;padding:8px;border-radius:6px;width:100%;text-align:left;';
      btn.addEventListener('click', () => {
        localStorage.setItem('store_id', String(s.id));
        document.body.removeChild(modal);
        resolve(s.id);
      });
      listEl.appendChild(btn);
    });
    box.querySelector('.cancel-store').addEventListener('click', () => {
      document.body.removeChild(modal);
      resolve(null);
    });
  });
};
