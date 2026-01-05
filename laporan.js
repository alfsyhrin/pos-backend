// ===== CURRENT FILTERS =====
let currentFilters = {
    keuangan: '30days', // atau 'all'
    produk: '30days',
    karyawan: '30days',
    dashboard: '30days'
};

// ===== PAGINATION STATE FOR KAS MASUK =====
let kasMasukPage = 1;
const kasMasukLimit = 5;

// ===== FILTER FUNCTIONALITY =====
function setFilter(tab, filter, btn) {
    currentFilters[tab] = filter;
    const filterSection = btn.parentElement;
    filterSection.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    if (tab === 'produk') {
        renderLaporanProduk();
    }
    if (tab === 'dashboard') {
        renderDashboard();
    }
    if (tab === 'keuangan') {
        kasMasukPage  = 1;
        renderLaporanKeuangan();
    }
    if (tab === 'karyawan') {
        renderLaporanKaryawan();
    }

    // ...tab lain tetap seperti sebelumnya
}

// ===== TAB FUNCTIONALITY =====
function showTab(tabName) {
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    document.getElementById('tab-' + tabName).classList.add('active');
    event.target.closest('.tab-btn').classList.add('active');
    if (tabName === 'produk') {
        renderLaporanProduk();
    }
    if (tabName === 'dashboard') {
        renderDashboard();
    }
    if (tabName === 'keuangan') {
        renderLaporanKeuangan();
    }
    if (tabName === 'karyawan') {
        renderLaporanKaryawan();
    }
    // ...tab lain tetap seperti sebelumnya
}

// ===== DATA =====
const topProductsData = [
    { name: 'iPhone 15 Pro Max', category: 'Elektronik', sales: 245, revenue: 367500000 },
    { name: 'Samsung Galaxy S24', category: 'Elektronik', sales: 198, revenue: 237600000 },
    { name: 'MacBook Pro M3', category: 'Komputer', sales: 156, revenue: 390000000 },
    { name: 'iPad Pro 12.9"', category: 'Tablet', sales: 134, revenue: 187600000 },
    { name: 'AirPods Pro 2', category: 'Aksesoris', sales: 287, revenue: 86100000 },
    { name: 'Sony WH-1000XM5', category: 'Audio', sales: 112, revenue: 44800000 },
    { name: 'Nintendo Switch OLED', category: 'Gaming', sales: 98, revenue: 49000000 },
    { name: 'Apple Watch Ultra 2', category: 'Wearable', sales: 89, revenue: 106800000 },
    { name: 'Canon EOS R6 Mark II', category: 'Kamera', sales: 45, revenue: 135000000 },
    { name: 'DJI Mini 4 Pro', category: 'Drone', sales: 67, revenue: 80400000 }
];

const lowStockData = [
    { name: 'Samsung Galaxy S24 Ultra', stock: 3, minStock: 10, status: 'critical' },
    { name: 'AirPods Max', stock: 5, minStock: 15, status: 'warning' },
    { name: 'Sony Alpha A7 IV', stock: 2, minStock: 8, status: 'critical' },
    { name: 'Bose QC Ultra', stock: 7, minStock: 12, status: 'warning' },
    { name: 'GoPro Hero 12', stock: 4, minStock: 10, status: 'warning' },
    { name: 'Kindle Paperwhite', stock: 6, minStock: 15, status: 'warning' },
    { name: 'Logitech MX Master 3S', stock: 8, minStock: 20, status: 'warning' },
    { name: 'Apple Pencil Pro', stock: 1, minStock: 10, status: 'critical' }
];

const employeePerformanceData = [
    { name: 'Ahmad Rizki', position: 'Sales Manager', performance: 98, sales: 125, target: 100 },
    { name: 'Siti Nurhaliza', position: 'Senior Sales', performance: 95, sales: 112, target: 100 },
    { name: 'Budi Santoso', position: 'Sales Executive', performance: 88, sales: 95, target: 100 },
    { name: 'Dewi Kartika', position: 'Sales Executive', performance: 92, sales: 108, target: 100 },
    { name: 'Rudi Hermawan', position: 'Junior Sales', performance: 78, sales: 72, target: 100 },
    { name: 'Eka Putri', position: 'Sales Executive', performance: 85, sales: 89, target: 100 }
];

const topSellersData = [
    { name: 'Ahmad Rizki', position: 'Sales Manager', totalSales: 18500000, transactions: 125 },
    { name: 'Siti Nurhaliza', position: 'Senior Sales', totalSales: 15200000, transactions: 112 },
    { name: 'Dewi Kartika', position: 'Sales Executive', totalSales: 12800000, transactions: 108 },
    { name: 'Budi Santoso', position: 'Sales Executive', totalSales: 11500000, transactions: 95 },
    { name: 'Eka Putri', position: 'Sales Executive', totalSales: 9800000, transactions: 89 },
    { name: 'Rudi Hermawan', position: 'Junior Sales', totalSales: 7200000, transactions: 72 }
];

// ===== RENDER FUNCTIONS =====
function renderTopProducts() {
    const container = document.getElementById('top-products');
    container.innerHTML = (window.topProductsData || []).map((product, index) => {
        let rankClass = 'normal';
        if (index === 0) rankClass = 'gold';
        else if (index === 1) rankClass = 'silver';
        else if (index === 2) rankClass = 'bronze';
        
        return `
            <div class="product-item">
                <div class="product-rank ${rankClass}">${index + 1}</div>
                <div class="product-info">
                    <div class="product-name">${product.name}</div>
                    <div class="product-category">${product.category}</div>
                </div>
                <div class="product-stats">
                    <div class="product-value">${formatCurrency(product.revenue)}</div>
                    <div class="product-qty">${product.sales} terjual</div>
                </div>
                <div class="product-actions">
                    <button onclick="loadPage('editProduk', {id: ${product.id}})" title="Edit Produk">
                        <span class="material-symbols-outlined">edit</span>
                    </button>
                    <button onclick="hapusProduk(${product.id})" title="Hapus Produk">
                        <span class="material-symbols-outlined">delete</span>
                    </button>
                </div>
            </div>
        `;
    }).join('');

    // ===== DATA DUMMY (KOMENTARI) =====
    // container.innerHTML = topProductsData.map(...).join('');
}

function renderLowStockProducts() {
    const container = document.getElementById('low-stock-products');
    container.innerHTML = (window.lowStockData || []).map(product => `
        <div class="low-stock-item ${product.status === 'critical' ? 'critical' : ''}">
            <div class="stock-icon">
                <span class="material-symbols-outlined">inventory</span>
            </div>
            <div class="stock-info">
                <div class="stock-name">${product.name}</div>
                <div class="stock-qty">Stok: ${product.stock} / Min: ${product.minStock}</div>
            </div>
            <span class="stock-badge ${product.status}">${product.status === 'critical' ? 'Kritis' : 'Menipis'}</span>
            <div class="stock-actions">
                <button onclick="loadPage('editProduk', {id: ${product.id}})" title="Edit Produk">
                    <span class="material-symbols-outlined">edit</span>
                </button>
                <button onclick="hapusProduk(${product.id})" title="Hapus Produk">
                    <span class="material-symbols-outlined">delete</span>
                </button>
            </div>
        </div>
    `).join('');

    // ===== DATA DUMMY (KOMENTARI) =====
    // container.innerHTML = lowStockData.map(...).join('');
}

function renderEmployeePerformance() {
    const container = document.getElementById('employee-performance');
    container.innerHTML = employeePerformanceData.map(emp => {
        let perfClass = 'average';
        if (emp.performance >= 95) perfClass = 'excellent';
        else if (emp.performance >= 85) perfClass = 'good';
        else if (emp.performance < 75) perfClass = 'poor';
        
        return `
            <div class="employee-item">
                <div class="employee-avatar">${emp.name.charAt(0)}</div>
                <div class="employee-info">
                    <div class="employee-name">${emp.name}</div>
                    <div class="employee-position">${emp.position}</div>
                </div>
                <div class="employee-stats">
                    <div class="employee-stat">
                        <div class="employee-stat-value">${emp.performance}%</div>
                        <div class="employee-stat-label">Performa</div>
                    </div>
                </div>
                <div>
                    <div class="performance-bar">
                        <div class="performance-fill ${perfClass}" style="width: ${emp.performance}%"></div>
                    </div>
                </div>
            </div>
        `;
    }).join('');
}

async function renderTopSellers() {
    const data = await fetchKaryawanData();
    let cashiers = data.cashiers || [];
    cashiers = cashiers.sort((a, b) => (b.total_penjualan || 0) - (a.total_penjualan || 0));
    const container = document.getElementById('top-sellers');
    container.innerHTML = cashiers.slice(0, 5).map((emp, index) => {
        let rankClass = 'normal';
        if (index === 0) rankClass = 'gold';
        else if (index === 1) rankClass = 'silver';
        else if (index === 2) rankClass = 'bronze';

        return `
            <div class="employee-item">
                <div class="product-rank ${rankClass}">${index + 1}</div>
                <div class="employee-info">
                    <div class="employee-name">${emp.name}</div>
                    <div class="employee-position">${emp.role}</div>
                </div>
                <div class="employee-stats">
                    <div class="employee-stat">
                        <div class="employee-stat-value">Rp ${emp.total_penjualan.toLocaleString('id-ID')}</div>
                        <div class="employee-stat-label">${emp.total_transaksi} transaksi</div>
                    </div>
                </div>
            </div>
        `;
    }).join('');

    // ===== DATA DUMMY (KOMENTARI) =====
    // container.innerHTML = topSellersData.map(...).join('');
}

// ===== CHART INITIALIZATION =====
let charts = {};

function initDashboardCharts() {
    Object.keys(charts).forEach(key => {
        if (charts[key]) charts[key].destroy();
    });

    const labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    
    Chart.defaults.color = '#818386';
    Chart.defaults.borderColor = '#2a2a2a';

    // Donut Chart
    const ctxDonut = document.getElementById('chartDonut').getContext('2d');
    charts.donut = new Chart(ctxDonut, {
        type: 'doughnut',
        data: {
            labels: ['Masuk', 'Keluar'],
            datasets: [{
                data: [45000000, 20000000],
                backgroundColor: ['#328E6E', '#E43636'],
                borderColor: '#1a1a1a',
                borderWidth: 3,
                hoverOffset: 8
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            cutout: '60%',
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: '#1a1a1a',
                    titleColor: '#f2f2f2',
                    bodyColor: '#f2f2f2',
                    borderColor: '#2a2a2a',
                    borderWidth: 1,
                    padding: 12,
                    cornerRadius: 10,
                    callbacks: {
                        label: function(context) {
                            return context.label + ': ' + formatCurrency(context.raw);
                        }
                    }
                }
            }
        }
    });

    // Kas Keluar Chart
    const ctxKasKeluar = document.getElementById('chartKasKeluar').getContext('2d');
    charts.kasKeluar = new Chart(ctxKasKeluar, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Kas Keluar',
                data: [2500000, 3200000, 2800000, 3500000, 3000000, 2200000, 2800000],
                borderColor: '#E43636',
                backgroundColor: 'rgba(228, 54, 54, 0.1)',
                fill: true,
                tension: 0.4,
                borderWidth: 2,
                pointRadius: 0,
                pointHoverRadius: 5
            }]
        },
        options: getChartOptions()
    });

    // Saldo Chart
    const ctxSaldo = document.getElementById('chartSaldo').getContext('2d');
    charts.saldo = new Chart(ctxSaldo, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Saldo',
                data: [25000000, 30000000, 35000000, 38000000, 42000000, 45000000, 47000000],
                borderColor: '#328E6E',
                backgroundColor: 'rgba(50, 142, 110, 0.1)',
                fill: true,
                tension: 0.4,
                borderWidth: 2,
                pointRadius: 0,
                pointHoverRadius: 5
            }]
        },
        options: getChartOptions()
    });

    // Kas Masuk Chart
    const ctxKasMasuk = document.getElementById('chartKasMasuk').getContext('2d');
    charts.kasMasuk = new Chart(ctxKasMasuk, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Kas Masuk',
                data: [5000000, 6000000, 7500000, 8000000, 9000000, 10000000, 9500000],
                borderColor: '#328E6E',
                backgroundColor: 'rgba(50, 142, 110, 0.1)',
                fill: true,
                tension: 0.4,
                borderWidth: 2,
                pointRadius: 0,
                pointHoverRadius: 5
            }]
        },
        options: getChartOptions()
    });

    // Penjualan Tertinggi Chart
    const ctxTertinggi = document.getElementById('chartTertinggi').getContext('2d');
    charts.tertinggi = new Chart(ctxTertinggi, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Tertinggi',
                data: [800000, 1200000, 1500000, 1400000, 1800000, 2100000, 1900000],
                borderColor: '#328E6E',
                backgroundColor: 'rgba(50, 142, 110, 0.1)',
                fill: true,
                tension: 0.4,
                borderWidth: 2,
                pointRadius: 0,
                pointHoverRadius: 5
            }]
        },
        options: getChartOptions()
    });

    // Penjualan Terendah Chart
    const ctxTerendah = document.getElementById('chartTerendah').getContext('2d');
    charts.terendah = new Chart(ctxTerendah, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Terendah',
                data: [25000, 32000, 28000, 18000, 22000, 35000, 15000],
                borderColor: '#E43636',
                backgroundColor: 'rgba(228, 54, 54, 0.1)',
                fill: true,
                tension: 0.4,
                borderWidth: 2,
                pointRadius: 0,
                pointHoverRadius: 5
            }]
        },
        options: getChartOptions()
    });

    // Rata-rata Harian Chart
    const ctxRataHarian = document.getElementById('chartRataHarian').getContext('2d');
    charts.rataHarian = new Chart(ctxRataHarian, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Rata-rata',
                data: [350000, 420000, 480000, 510000, 550000, 680000, 510000],
                borderColor: '#328E6E',
                backgroundColor: 'rgba(50, 142, 110, 0.1)',
                fill: true,
                tension: 0.4,
                borderWidth: 2,
                pointRadius: 0,
                pointHoverRadius: 5
            }]
        },
        options: getChartOptions()
    });
}

function getChartOptions() {
    return {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
            legend: { display: false },
            tooltip: {
                backgroundColor: '#1a1a1a',
                titleColor: '#f2f2f2',
                bodyColor: '#f2f2f2',
                borderColor: '#2a2a2a',
                borderWidth: 1,
                padding: 12,
                cornerRadius: 10,
                callbacks: {
                    label: function(context) {
                        return formatCurrency(context.raw);
                    }
                }
            }
        },
        scales: {
            x: {
                grid: { display: false },
                ticks: { 
                    color: '#818386', 
                    font: { family: 'Asap', size: 10 } 
                }
            },
            y: {
                grid: { color: '#2a2a2a', drawBorder: false },
                ticks: {
                    color: '#818386',
                    font: { family: 'Asap', size: 10 },
                    callback: function(value) {
                        if (value >= 1000000) {
                            return (value / 1000000).toFixed(1) + '.000.000';
                        } else if (value >= 1000) {
                            return (value / 1000).toFixed(0) + '.000';
                        }
                        return value;
                    }
                }
            }
        }
    };
}

// ===== EXPORT FUNCTIONS =====
async function exportPDF(tabName) {
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF();
    
    const titles = {
        keuangan: 'Laporan Keuangan',
        dashboard: 'Dashboard',
        produk: 'Laporan Produk',
        karyawan: 'Laporan Karyawan'
    };

    doc.setFontSize(20);
    doc.setTextColor(228, 54, 54);
    doc.text(titles[tabName], 14, 22);
    
    doc.setFontSize(10);
    doc.setTextColor(129, 131, 134);
    doc.text('Tanggal: ' + new Date().toLocaleDateString('id-ID'), 14, 30);
    
    let startY = 40;

    if (tabName === 'keuangan') {
        doc.setFontSize(14);
        doc.setTextColor(30, 41, 59);
        doc.text('Ringkasan Keuangan', 14, startY);
        
        doc.autoTable({
            startY: startY + 5,
            head: [['Keterangan', 'Jumlah']],
            body: [
                ['Total Pembayaran', 'Rp 15.750.000'],
                ['Banyak Transaksi', '234'],
                ['Margin', '32.5%'],
                ['Total Pendapatan', 'Rp 18.500.000'],
                ['Diskon', 'Rp 850.000'],
                ['Pendapatan Bersih', 'Rp 17.650.000'],
                ['Modal/HPP', 'Rp 11.850.000'],
                ['Laba Kotor', 'Rp 5.800.000'],
                ['Laba Bersih', 'Rp 4.250.000'],
                ['Rata-rata Transaksi', 'Rp 67.308']
            ],
            theme: 'grid',
            headStyles: { fillColor: [228, 54, 54] }
        });
    } else if (tabName === 'produk') {
        doc.setFontSize(14);
        doc.text('Ringkasan Produk', 14, startY);
        
        doc.autoTable({
            startY: startY + 5,
            head: [['Keterangan', 'Jumlah']],
            body: [
                ['Total Produk', '1,247'],
                ['Total Produk Terjual', '3,856'],
                ['Stok Menipis', '23'],
                ['Stok Habis', '8']
            ],
            theme: 'grid',
            headStyles: { fillColor: [228, 54, 54] }
        });

        doc.text('10 Produk Teratas', 14, doc.lastAutoTable.finalY + 15);
        doc.autoTable({
            startY: doc.lastAutoTable.finalY + 20,
            head: [['Rank', 'Nama Produk', 'Kategori', 'Terjual', 'Pendapatan']],
            body: topProductsData.map((p, i) => [
                i + 1, p.name, p.category, p.sales, formatCurrency(p.revenue)
            ]),
            theme: 'grid',
            headStyles: { fillColor: [228, 54, 54] }
        });
    } else if (tabName === 'karyawan') {
        doc.setFontSize(14);
        doc.text('Ringkasan Karyawan', 14, startY);
        
        doc.autoTable({
            startY: startY + 5,
            head: [['Keterangan', 'Jumlah']],
            body: [
                ['Total Karyawan', '48'],
                ['Rata-rata Performa', '89.2%'],
                ['Total Penjualan', 'Rp 85.200.000'],
                ['Kehadiran', '98.5%']
            ],
            theme: 'grid',
            headStyles: { fillColor: [228, 54, 54] }
        });

        doc.text('Performa Karyawan', 14, doc.lastAutoTable.finalY + 15);
        doc.autoTable({
            startY: doc.lastAutoTable.finalY + 20,
            head: [['Nama', 'Posisi', 'Performa', 'Target']],
            body: employeePerformanceData.map(e => [
                e.name, e.position, e.performance + '%', e.target + '%'
            ]),
            theme: 'grid',
            headStyles: { fillColor: [228, 54, 54] }
        });
    } else if (tabName === 'dashboard') {
        doc.setFontSize(12);
        doc.text('Ringkasan Dashboard', 14, startY);
        
        doc.autoTable({
            startY: startY + 5,
            head: [['Keterangan', 'Jumlah']],
            body: [
                ['Total Transaksi', '1,234'],
                ['Total Kas Masuk', 'Rp 45.000.000'],
                ['Total Kas Keluar', 'Rp 20.000.000'],
                ['Saldo', 'Rp 47.000.000']
            ],
            theme: 'grid',
            headStyles: { fillColor: [228, 54, 54] }
        });
    }

    doc.save(`${titles[tabName]}_${new Date().toISOString().split('T')[0]}.pdf`);
}

function exportExcel(tabName) {
    const titles = {
        keuangan: 'Laporan Keuangan',
        dashboard: 'Dashboard',
        produk: 'Laporan Produk',
        karyawan: 'Laporan Karyawan'
    };

    let data = [];
    let sheetName = titles[tabName];

    if (tabName === 'keuangan') {
        data = [
            ['Laporan Keuangan'],
            ['Tanggal Export:', new Date().toLocaleDateString('id-ID')],
            [],
            ['Ringkasan'],
            ['Keterangan', 'Jumlah'],
            ['Total Pembayaran', 15750000],
            ['Banyak Transaksi', 234],
            ['Margin (%)', 32.5],
            ['Total Pendapatan', 18500000],
            ['Diskon', 850000],
            ['Pendapatan Bersih', 17650000],
            ['Modal/HPP', 11850000],
            ['Laba Kotor', 5800000],
            ['Laba Bersih', 4250000],
            ['Rata-rata Transaksi', 67308]
        ];
    } else if (tabName === 'produk') {
        data = [
            ['Laporan Produk'],
            ['Tanggal Export:', new Date().toLocaleDateString('id-ID')],
            [],
            ['Ringkasan'],
            ['Keterangan', 'Jumlah'],
            ['Total Produk', 1247],
            ['Total Produk Terjual', 3856],
            ['Stok Menipis', 23],
            ['Stok Habis', 8],
            [],
            ['10 Produk Teratas'],
            ['Rank', 'Nama Produk', 'Kategori', 'Terjual', 'Pendapatan'],
            ...topProductsData.map((p, i) => [i + 1, p.name, p.category, p.sales, p.revenue])
        ];
    } else if (tabName === 'karyawan') {
        data = [
            ['Laporan Karyawan'],
            ['Tanggal Export:', new Date().toLocaleDateString('id-ID')],
            [],
            ['Ringkasan'],
            ['Keterangan', 'Jumlah'],
            ['Total Karyawan', 48],
            ['Rata-rata Performa (%)', 89.2],
            ['Total Penjualan', 85200000],
            ['Kehadiran (%)', 98.5],
            [],
            ['Performa Karyawan'],
            ['Nama', 'Posisi', 'Performa (%)', 'Sales', 'Target'],
            ...employeePerformanceData.map(e => [e.name, e.position, e.performance, e.sales, e.target])
        ];
    } else if (tabName === 'dashboard') {
        data = [
            ['Dashboard'],
            ['Tanggal Export:', new Date().toLocaleDateString('id-ID')],
            [],
            ['Ringkasan'],
            ['Keterangan', 'Jumlah'],
            ['Total Transaksi', 1234],
            ['Total Kas Masuk', 45000000],
            ['Total Kas Keluar', 20000000],
            ['Saldo', 47000000]
        ];
    }

    const ws = XLSX.utils.aoa_to_sheet(data);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, sheetName);
    XLSX.writeFile(wb, `${titles[tabName]}_${new Date().toISOString().split('T')[0]}.xlsx`);
}

// ===== UTILITIES =====
function formatCurrency(value) {
    if (value >= 1000000000) {
        return 'Rp ' + (value / 1000000000).toFixed(1) + ' M';
    } else if (value >= 1000000) {
        return 'Rp ' + (value / 1000000).toFixed(1) + ' Jt';
    } else if (value >= 1000) {
        return 'Rp ' + (value / 1000).toFixed(0) + ' Rb';
    }
    return 'Rp ' + value.toLocaleString('id-ID');
}

function getDateRange(filter) {
    const today = new Date();
    let start, end;
    end = today.toISOString().slice(0,10);
    if (filter === 'today') {
        start = end;
    } else if (filter === '7days') {
        const d = new Date(today); d.setDate(d.getDate() - 6);
        start = d.toISOString().slice(0,10);
    } else if (filter === '30days') {
        const d = new Date(today); d.setDate(d.getDate() - 29);
        start = d.toISOString().slice(0,10);
    } else if (filter === '1year') {
        const d = new Date(today); d.setFullYear(d.getFullYear() - 1);
        start = d.toISOString().slice(0,10);
    } else if (filter === 'all') {
        start = '2000-01-01'; // tanggal awal data
    } else {
        start = end;
    }
    return { start, end };
}

// ===== API CONFIGURATION =====
const API_BASE = 'http://103.126.116.119:8001/api';
const store_id = localStorage.getItem('store_id');
const token = localStorage.getItem('token');

async function fetchLaporanKeuangan(filter) {
    const { start, end } = getDateRange(filter);
    const res = await fetch(`${API_BASE}/stores/${store_id}/reports/summary?start=${start}&end=${end}`, {
        headers: { Authorization: `Bearer ${token}` }
    });
    const json = await res.json();
    return json.data || {};
}

async function fetchLaporanProduk(filter) {
    const { start, end } = getDateRange(filter);
    const res = await fetch(`${API_BASE}/stores/${store_id}/reports/products?start=${start}&end=${end}`, {
        headers: { Authorization: `Bearer ${token}` }
    });
    const json = await res.json();
    return json.data || {};
}

async function fetchLaporanKaryawan(filter) {
    const { start, end } = getDateRange(filter);
    const res = await fetch(`${API_BASE}/stores/${store_id}/reports/cashiers?start=${start}&end=${end}`, {
        headers: { Authorization: `Bearer ${token}` }
    });
    const json = await res.json();
    return json.data || {};
}

async function fetchKaryawanData() {
    const storeId = store_id || 1;
    const tokenVal = token || '';
    const { start, end } = getDateRange(currentFilters['karyawan']);
    const endpoint = `${API_BASE}/stores/${storeId}/reports/cashiers?start=${start}&end=${end}`;
    const res = await fetch(endpoint, {
        headers: { 'Authorization': 'Bearer ' + tokenVal }
    });
    const json = await res.json();
    return json.data || {};
}

// ===== INITIALIZATION =====
document.addEventListener('DOMContentLoaded', () => {
  window.updateHeaderStoreName();
  renderDashboard();
  renderLaporanKeuangan();
  renderLaporanProduk();
  renderLaporanKaryawan();
  renderTopProducts();
  renderLowStockProducts();
  renderEmployeePerformance();
  renderTopSellers();
});

async function renderLaporanKeuangan() {
    const data = await fetchLaporanKeuangan(currentFilters.keuangan);

    // Update header stats
    document.querySelectorAll('.header-stat-card .stat-value')[0].textContent = formatCurrency(data.total_pendapatan || 0);
    document.querySelectorAll('.header-stat-card .stat-value')[1].textContent = data.total_transaksi || 0;
    document.querySelectorAll('.header-stat-card .stat-value')[2].textContent = data.margin || '0%';

    // Update stat cards
    const statValues = document.querySelectorAll('.stat-card-new .stat-value');
    statValues[0].textContent = formatCurrency(data.total_pendapatan || 0);
    statValues[1].textContent = formatCurrency(data.total_diskon || 0);
    statValues[2].textContent = formatCurrency(data.net_revenue || 0);
    statValues[3].textContent = formatCurrency(data.total_hpp || 0);
    statValues[4].textContent = formatCurrency(data.gross_profit || 0);
    statValues[5].textContent = formatCurrency(data.net_profit || 0);

    // Update single stat
    document.querySelector('.stat-single .stat-value').textContent = formatCurrency(data.avg_daily || 0);

    // Top products
    window.topProductsData = (data.top_products || []).map(p => ({
        name: p.name,
        category: p.sku || '',
        sales: p.sold,
        revenue: p.revenue
    }));
    renderTopProducts();

    // Low stock
    window.lowStockData = (data.stok_menipis || []).map(p => ({
        name: p.name,
        stock: p.remaining,
        minStock: 10,
        status: (p.remaining <= 3 ? 'critical' : 'warning')
    }));
    renderLowStockProducts();

    renderKasMasukTerbaru();
}

async function renderLaporanProduk() {
    const data = await fetchLaporanProduk(currentFilters.produk);

    // Update stat cards
    const statValues = document.querySelectorAll('#tab-produk .stat-value');
    statValues[0].textContent = data.total_products || 0;
    statValues[1].textContent = data.total_sold || 0;
    statValues[2].textContent = (data.stok_menipis || []).length;
    statValues[3].textContent = data.stok_habis || 0;

    // Top products
    window.topProductsData = (data.top_products || []).map(p => ({
        name: p.name,
        category: p.sku || '',
        sales: p.sold,
        revenue: p.revenue
    }));
    renderTopProducts();

    // Low stock
    window.lowStockData = (data.stok_menipis || []).map(p => ({
        name: p.name,
        stock: p.remaining,
        minStock: 10,
        status: (p.remaining <= 3 ? 'critical' : 'warning')
    }));
    renderLowStockProducts();

    // ===== DATA DUMMY (KOMENTARI) =====
    // statValues[0].textContent = '1,247';
    // statValues[1].textContent = '3,856';
    // statValues[2].textContent = '23';
    // statValues[3].textContent = '8';
}

async function renderLaporanKaryawan() {
    const data = await fetchLaporanKaryawan(currentFilters.karyawan);

    // Update stat cards
    const statValues = document.querySelectorAll('#tab-karyawan .stat-value');
    statValues[0].textContent = data.total_karyawan || 0;
    statValues[1].textContent = (data.avg_performance || 0) + '%';
    statValues[2].textContent = formatCurrency(data.total_penjualan || 0);
    statValues[3].textContent = (data.avg_attendance || 0) + '%';

    // Employee performance
    window.employeePerformanceData = (data.cashiers || []).map(emp => ({
        name: emp.name,
        position: emp.role,
        performance: emp.total_transaksi || 0,
        sales: emp.total_penjualan || 0,
        target: 100
    }));
    renderEmployeePerformance();

    // Top sellers
    window.topSellersData = (data.cashiers || []).map(emp => ({
        name: emp.name,
        position: emp.role,
        totalSales: emp.total_penjualan || 0,
        transactions: emp.total_transaksi || 0
    }));
    renderTopSellers();
}

async function generateDailyReport() {
    const storeId = localStorage.getItem('store_id');
    const token = localStorage.getItem('token');
    const date = new Date().toISOString().slice(0,10);
    const btn = document.getElementById('btn-generate-daily');
    const statusEl = document.getElementById('generate-daily-status');
    btn.disabled = true;
    statusEl.textContent = 'Memproses...';
    try {
        const res = await fetch(`http://103.126.116.119:8001/api/stores/${storeId}/reports/daily/generate?date=${date}`, {
            method: 'POST',
            headers: { 'Authorization': 'Bearer ' + token }
        });
        const data = await res.json();
        if (data.success) {
            statusEl.textContent = 'Laporan harian berhasil disimpan!';
            statusEl.style.color = '#328E6E';
        } else {
            statusEl.textContent = data.message || 'Gagal generate laporan!';
            statusEl.style.color = '#E43636';
        }
    } catch (e) {
        statusEl.textContent = 'Gagal generate laporan!';
        statusEl.style.color = '#E43636';
    }
    btn.disabled = false;
}

// Cek apakah laporan hari ini sudah ada, disable tombol jika sudah
async function checkDailyReportExists() {
    const storeId = localStorage.getItem('store_id');
    const token = localStorage.getItem('token');
    const date = new Date().toISOString().slice(0,10);
    const btn = document.getElementById('btn-generate-daily');
    const statusEl = document.getElementById('generate-daily-status');
    try {
        const res = await fetch(`http://103.126.116.119:8001/api/stores/${storeId}/reports/daily?date=${date}`, {
            headers: { 'Authorization': 'Bearer ' + token }
        });
        const data = await res.json();
        if (data.success && data.data && data.data.id) {
            btn.disabled = true;
            statusEl.textContent = 'Laporan hari ini sudah ada.';
            statusEl.style.color = '#328E6E';
        } else {
            btn.disabled = false;
            statusEl.textContent = '';
        }
    } catch (e) {
        btn.disabled = false;
        statusEl.textContent = '';
    }
}

// Inisialisasi tombol saat halaman laporan dibuka
document.addEventListener('DOMContentLoaded', () => {
    const btn = document.getElementById('btn-generate-daily');
    if (btn) {
        btn.onclick = generateDailyReport;
        checkDailyReportExists();
    }
});

async function renderEmployeePerformance() {
    const data = await fetchKaryawanData();
    const cashiers = data.cashiers || [];
    const container = document.getElementById('employee-performance');
    container.innerHTML = cashiers.map(emp => {
        let perfClass = 'average';
        const performance = emp.total_transaksi || 0;
        if (performance >= 95) perfClass = 'excellent';
        else if (performance >= 85) perfClass = 'good';
        else if (performance < 75) perfClass = 'poor';

        return `
            <div class="employee-item">
                <div class="employee-avatar">${emp.name.charAt(0)}</div>
                <div class="employee-info">
                    <div class="employee-name">${emp.name}</div>
                    <div class="employee-position">${emp.role}</div>
                </div>
                <div class="employee-stats">
                    <div class="employee-stat">
                        <div class="employee-stat-value">${performance}</div>
                        <div class="employee-stat-label">Transaksi</div>
                    </div>
                </div>
                <div>
                    <div class="performance-bar">
                        <div class="performance-fill ${perfClass}" style="width: ${performance}%"></div>
                    </div>
                </div>
            </div>
        `;
    }).join('');

    // ===== DATA DUMMY (KOMENTARI) =====
    // container.innerHTML = employeePerformanceData.map(...).join('');
}

async function renderDashboard() {
    const data = await fetchLaporanKeuangan(currentFilters.dashboard || '30days');

    // Kas Masuk
    const kasMasukEl = document.getElementById('dashboard-kas-masuk');
    if (kasMasukEl) {
        const valueEl = kasMasukEl.querySelector('.card-value');
        if (valueEl) valueEl.textContent = formatCurrency(data.total_pendapatan || 0);
    }

    // Total Transaksi
    const totalTransaksiEl = document.getElementById('dashboard-total-transaksi');
    if (totalTransaksiEl) totalTransaksiEl.textContent = data.total_transaksi || 0;

    // Penjualan Tertinggi
    const tertinggiEl = document.getElementById('dashboard-tertinggi');
    if (tertinggiEl) {
        const valueEl = tertinggiEl.querySelector('.card-value');
        if (valueEl) valueEl.textContent = formatCurrency(data.best_sales_day || 0);
    }

    // Penjualan Terendah
    const terendahEl = document.getElementById('dashboard-terendah');
    if (terendahEl) {
        const valueEl = terendahEl.querySelector('.card-value');
        if (valueEl) valueEl.textContent = formatCurrency(data.lowest_sales_day || 0);
    }

    // Rata-rata Harian
    const rataEl = document.getElementById('dashboard-ratarata');
    if (rataEl) {
        const valueEl = rataEl.querySelector('.card-value');
        if (valueEl) valueEl.textContent = formatCurrency(data.avg_daily || 0);
    }

    // Sembunyikan widget yang tidak ada datanya
    const kasKeluar = document.getElementById('dashboard-kas-keluar');
    const saldo = document.getElementById('dashboard-saldo');
    const donut = document.getElementById('dashboard-donut');
    if (kasKeluar) kasKeluar.style.display = 'none';
    if (saldo) saldo.style.display = 'none';
    if (donut) donut.style.display = 'none';
}

// Ambil 5 transaksi terbaru untuk kas masuk
async function renderKasMasukTerbaru() {
    const transactions = await fetchTransactions({ limit: kasMasukLimit, page: kasMasukPage });
    const container = document.getElementById('kas-masuk-terbaru');
    if (!container) return;

    if (!transactions || transactions.length === 0) {
        container.innerHTML = `<tr><td colspan="3" style="text-align:center;color:#888;">Tidak ada data kas masuk.</td></tr>`;
    } else {
        container.innerHTML = transactions.map(trx => `
            <tr>
                <td>${trx.createdAt ? new Date(trx.createdAt).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }) : '-'}</td>
                <td>${trx.note || trx.description || (trx.items && trx.items[0] && trx.items[0].name) || '-'}</td>
                <td><span class="badge badge-success">${formatCurrency(trx.total || 0)}</span></td>
            </tr>
        `).join('');
    }

    // Update pagination info & button state
    const pageInfo = document.getElementById('kas-masuk-page-info');
    if (pageInfo) pageInfo.textContent = `Halaman ${kasMasukPage}`;

    // Enable/disable tombol
    document.getElementById('kas-masuk-prev').disabled = kasMasukPage === 1;
    document.getElementById('kas-masuk-next').disabled = !transactions || transactions.length < kasMasukLimit;
}

function kasMasukPrevPage() {
    if (kasMasukPage > 1) {
        kasMasukPage--;
        renderKasMasukTerbaru();
    }
}
function kasMasukNextPage() {
    kasMasukPage++;
    renderKasMasukTerbaru();
}