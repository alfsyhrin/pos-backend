import 'package:flutter/material.dart';
import '../shared/app_colors.dart';

// Services & models (realtime)
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import '../services/product_service.dart';
import '../services/transaction_service.dart';

/// =====================
/// COMPAT: Product.isDraft
/// =====================
/// FIX untuk error:
/// "The getter 'isDraft' isn't defined for the type 'Product'."
///
/// Karena model Product Anda belum punya isDraft,
/// extension ini membuatnya selalu tersedia (default: false).
extension ProductDraftCompat on Product {
  bool get isDraft => false;
}

class ReportScreen extends StatefulWidget {
  final bool embedded;
  const ReportScreen({super.key, this.embedded = false});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  /// Default tab: LAPORAN KEUANGAN (di atas / paling awal)
  int _tabIndex = 0;

  int _selectedYear = DateTime.now().year;
  final Set<int> _selectedMonths = {DateTime.now().month};

  @override
  void initState() {
    super.initState();
    // Pastikan produk ada (kalau Anda memang pakai seed)
    ProductService.instance.seedIfEmpty();
  }

  void _resetFilter() {
    setState(() {
      _selectedYear = DateTime.now().year;
      _selectedMonths
        ..clear()
        ..add(DateTime.now().month);
    });
  }

  bool _txMatchesFilter(TransactionData tx) {
    if (tx.createdAt.year != _selectedYear) return false;
    if (_selectedMonths.isEmpty) return true;
    return _selectedMonths.contains(tx.createdAt.month);
  }

  void _openFilterSheet({
    required int selectedYear,
    required Set<int> selectedMonths,
    required ValueChanged<int> onYearChanged,
    required ValueChanged<int> onMonthToggle,
    required VoidCallback onReset,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kDarkSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kDarkBorder),
              boxShadow: [kSoftShadow()],
            ),
            child: _FilterPanelContent(
              selectedYear: selectedYear,
              selectedMonths: selectedMonths,
              onYearChanged: onYearChanged,
              onMonthToggle: onMonthToggle,
              onReset: onReset,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Container(
      color: kDarkBg,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;

          // Breakpoints lebih rapi untuk mobile/tablet/desktop
          final isWide = w >= 1100; // desktop
          final panelWidth = isWide ? 260.0 : 0.0;

          return Row(
            children: [
              if (isWide)
                _FilterPanel(
                  width: panelWidth,
                  selectedYear: _selectedYear,
                  selectedMonths: _selectedMonths,
                  onYearChanged: (y) => setState(() => _selectedYear = y),
                  onMonthToggle: (m) {
                    setState(() {
                      if (_selectedMonths.contains(m)) {
                        if (_selectedMonths.length > 1) _selectedMonths.remove(m);
                      } else {
                        _selectedMonths.add(m);
                      }
                    });
                  },
                  onReset: _resetFilter,
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(isWide ? 16 : 14, 14, isWide ? 16 : 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopTabs(
                        tabIndex: _tabIndex,
                        onTabChanged: (i) => setState(() => _tabIndex = i),
                        onExport: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Export masih stub (belum dihubungkan)')),
                          );
                        },
                        showFilterButton: !isWide,
                        onOpenFilters: () => _openFilterSheet(
                          selectedYear: _selectedYear,
                          selectedMonths: _selectedMonths,
                          onYearChanged: (y) => setState(() => _selectedYear = y),
                          onMonthToggle: (m) {
                            setState(() {
                              if (_selectedMonths.contains(m)) {
                                if (_selectedMonths.length > 1) _selectedMonths.remove(m);
                              } else {
                                _selectedMonths.add(m);
                              }
                            });
                          },
                          onReset: _resetFilter,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Expanded(
                        child: ValueListenableBuilder<List<TransactionData>>(
                          valueListenable: TransactionService.instance.transactions,
                          builder: (context, txList, _) {
                            final filteredTx = txList.where(_txMatchesFilter).toList();

                            return ValueListenableBuilder<List<Product>>(
                              valueListenable: ProductService.instance.notifier,
                              builder: (context, products, __) {
                                final data = _ReportData.fromServices(
                                  transactions: filteredTx,
                                  products: products,
                                  lowStockThreshold: 5,
                                );

                                return IndexedStack(
                                  index: _tabIndex,
                                  children: [
                                    // 0: Laporan Keuangan (paling atas / paling awal)
                                    _OverviewView(data: data),
                                    // 1: Dashboard Finance
                                    _FinanceDashboardView(data: data),
                                    // 2: Produk
                                    _ProdukView(data: data),
                                    // 3: Karyawan
                                    _KaryawanView(data: data),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(child: body),
    );
  }
}

/* ============================== DATA AGGREGATION ============================== */

class _ReportData {
  // Finance dashboard
  final int cashIn;
  final int cashOut; // belum tersedia dari model -> default 0
  final int balance;
  final double inRatio;

  // Laporan keuangan
  final int totalRevenue;
  final int totalCost; // belum tersedia dari model -> default 0
  final int netProfit; // revenue - cost
  final int avgTicket;
  final int totalTransactions;
  final String marginPct;

  // Day stats
  final int bestSalesDay;
  final int lowestSalesDay;
  final int avgDaily;

  // Produk
  final List<_TopProductAgg> topProducts;
  final List<_LowStockAgg> lowStocks;

  // Karyawan (placeholder)
  final int karyawanTopTx;
  final String karyawanTopTitle;

  const _ReportData({
    required this.cashIn,
    required this.cashOut,
    required this.balance,
    required this.inRatio,
    required this.totalRevenue,
    required this.totalCost,
    required this.netProfit,
    required this.avgTicket,
    required this.totalTransactions,
    required this.marginPct,
    required this.bestSalesDay,
    required this.lowestSalesDay,
    required this.avgDaily,
    required this.topProducts,
    required this.lowStocks,
    required this.karyawanTopTx,
    required this.karyawanTopTitle,
  });

  static _ReportData fromServices({
    required List<TransactionData> transactions,
    required List<Product> products,
    int lowStockThreshold = 5,
  }) {
    // Revenue & tx count
    final totalRevenue = transactions.fold<int>(0, (s, tx) => s + tx.total.round());
    final totalTx = transactions.length;
    final avgTicket = totalTx == 0 ? 0 : (totalRevenue / totalTx).round();

    // Cost & profit (model transaksi belum menyimpan HPP)
    final totalCost = 0;
    final netProfit = totalRevenue - totalCost;
    final marginPct = totalRevenue <= 0
        ? '0%'
        : (((netProfit / totalRevenue) * 100).round()).toString() + '%';

    // Daily aggregation
    final Map<String, int> daily = {};
    for (final tx in transactions) {
      final key = _dayKey(tx.createdAt);
      daily[key] = (daily[key] ?? 0) + tx.total.round();
    }

    int best = 0;
    int lowest = 0;
    if (daily.isNotEmpty) {
      best = daily.values.reduce((a, b) => a > b ? a : b);
      lowest = daily.values.reduce((a, b) => a < b ? a : b);
    }
    final avgDaily = daily.isEmpty ? 0 : (totalRevenue / daily.length).round();

    // Top products aggregation
    final Map<String, _TopProductAgg> bySku = {};
    for (final tx in transactions) {
      for (final it in tx.items) {
        final sku = it.sku;
        final existing = bySku[sku];
        if (existing == null) {
          bySku[sku] = _TopProductAgg(
            sku: sku,
            name: it.name,
            sold: it.qty,
            revenue: it.lineTotal.round(),
          );
        } else {
          bySku[sku] = existing.copyWith(
            sold: existing.sold + it.qty,
            revenue: existing.revenue + it.lineTotal.round(),
          );
        }
      }
    }
    final topProducts = bySku.values.toList()
      ..sort((a, b) {
        final s = b.sold.compareTo(a.sold);
        if (s != 0) return s;
        return b.revenue.compareTo(a.revenue);
      });

    // Low stock
    final lowStocks = products
        .where((p) => !p.isDraft && p.stock <= lowStockThreshold)
        .map((p) => _LowStockAgg(name: p.name, remaining: p.stock))
        .toList()
      ..sort((a, b) => a.remaining.compareTo(b.remaining));

    // Karyawan placeholder
    final karyawanTopTx = totalTx;
    final karyawanTopTitle =
    totalTx == 0 ? 'Belum ada transaksi' : '$totalTx transaksi (semua kasir)';

    final cashIn = totalRevenue;
    final cashOut = 0;
    final balance = cashIn - cashOut;
    final inRatio = (cashIn + cashOut) == 0 ? 0.0 : (cashIn / (cashIn + cashOut));

    return _ReportData(
      cashIn: cashIn,
      cashOut: cashOut,
      balance: balance,
      inRatio: inRatio,
      totalRevenue: totalRevenue,
      totalCost: totalCost,
      netProfit: netProfit,
      avgTicket: avgTicket,
      totalTransactions: totalTx,
      marginPct: marginPct,
      bestSalesDay: best,
      lowestSalesDay: lowest,
      avgDaily: avgDaily,
      topProducts: topProducts,
      lowStocks: lowStocks,
      karyawanTopTx: karyawanTopTx,
      karyawanTopTitle: karyawanTopTitle,
    );
  }

  static String _dayKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get cashInLabel => formatRupiahInt(cashIn);
  String get cashOutLabel => formatRupiahInt(cashOut);
  String get balanceLabel => formatRupiahInt(balance);

  String get totalRevenueLabel => formatRupiahInt(totalRevenue);
  String get totalCostLabel => formatRupiahInt(totalCost);
  String get netProfitLabel => formatRupiahInt(netProfit);
  String get avgTicketLabel => formatRupiahInt(avgTicket);

  String get bestSalesLabel => formatRupiahInt(bestSalesDay);
  String get lowestSalesLabel => formatRupiahInt(lowestSalesDay);
  String get avgDailyLabel => formatRupiahInt(avgDaily);
}

class _TopProductAgg {
  final String sku;
  final String name;
  final int sold;
  final int revenue;

  const _TopProductAgg({
    required this.sku,
    required this.name,
    required this.sold,
    required this.revenue,
  });

  _TopProductAgg copyWith({int? sold, int? revenue}) => _TopProductAgg(
    sku: sku,
    name: name,
    sold: sold ?? this.sold,
    revenue: revenue ?? this.revenue,
  );

  String get revenueLabel => formatRupiahInt(revenue);
}

class _LowStockAgg {
  final String name;
  final int remaining;
  const _LowStockAgg({required this.name, required this.remaining});
}

/* ============================== TOP TABS ============================== */

class _TopTabs extends StatelessWidget {
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onExport;

  final bool showFilterButton;
  final VoidCallback? onOpenFilters;

  const _TopTabs({
    required this.tabIndex,
    required this.onTabChanged,
    required this.onExport,
    this.showFilterButton = false,
    this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    // Tabs dibuat horizontal scroll (anti overflow)
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _TabPill(
                  active: tabIndex == 0,
                  icon: Icons.bar_chart_rounded,
                  label: 'Laporan Keuangan',
                  onTap: () => onTabChanged(0),
                ),
                const SizedBox(width: 10),
                _TabPill(
                  active: tabIndex == 1,
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  onTap: () => onTabChanged(1),
                ),
                const SizedBox(width: 10),
                _TabPill(
                  active: tabIndex == 2,
                  icon: Icons.inventory_2_rounded,
                  label: 'Produk',
                  onTap: () => onTabChanged(2),
                ),
                const SizedBox(width: 10),
                _TabPill(
                  active: tabIndex == 3,
                  icon: Icons.groups_2_rounded,
                  label: 'Karyawan',
                  onTap: () => onTabChanged(3),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        const _RealtimePill(),
        const SizedBox(width: 10),
        if (showFilterButton)
          _IconSquareButton(
            icon: Icons.tune_rounded,
            onTap: onOpenFilters ?? () {},
            tooltip: 'Filter',
          ),
        if (showFilterButton) const SizedBox(width: 10),
        _ExportButton(onTap: onExport),
      ],
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _IconSquareButton({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kDarkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kDarkBorder),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );

    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

class _TabPill extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TabPill({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? kMaroon : kDarkSurface;
    final border = active ? kMaroon : kDarkBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RealtimePill extends StatelessWidget {
  const _RealtimePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kDarkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Realtime',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExportButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: kMaroon,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kMaroon),
          ),
          child: const Row(
            children: [
              Icon(Icons.download_rounded, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Export',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================== FILTER PANEL ============================== */

class _FilterPanel extends StatelessWidget {
  final double width;
  final int selectedYear;
  final Set<int> selectedMonths;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthToggle;
  final VoidCallback onReset;

  const _FilterPanel({
    required this.width,
    required this.selectedYear,
    required this.selectedMonths,
    required this.onYearChanged,
    required this.onMonthToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        color: kDarkBg,
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: _FilterPanelContent(
        selectedYear: selectedYear,
        selectedMonths: selectedMonths,
        onYearChanged: onYearChanged,
        onMonthToggle: onMonthToggle,
        onReset: onReset,
      ),
    );
  }
}

class _FilterPanelContent extends StatelessWidget {
  final int selectedYear;
  final Set<int> selectedMonths;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthToggle;
  final VoidCallback onReset;

  const _FilterPanelContent({
    required this.selectedYear,
    required this.selectedMonths,
    required this.onYearChanged,
    required this.onMonthToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'YEAR',
          style: TextStyle(
            color: kTextMuted,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        _YearButton(year: 2025, active: selectedYear == 2025, onTap: () => onYearChanged(2025)),
        const SizedBox(height: 10),
        _YearButton(year: 2026, active: selectedYear == 2026, onTap: () => onYearChanged(2026)),
        const SizedBox(height: 10),
        _YearButton(year: 2027, active: selectedYear == 2027, onTap: () => onYearChanged(2027)),
        const SizedBox(height: 18),
        const Text(
          'MONTH',
          style: TextStyle(
            color: kTextMuted,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(12, (i) {
            final m = i + 1;
            final label = _monthShort(m);
            final active = selectedMonths.contains(m);
            return _MonthChip(label: label, active: active, onTap: () => onMonthToggle(m));
          }),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text(
              'Reset',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: kMaroon,
              side: BorderSide(color: kMaroon),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  static String _monthShort(int m) {
    const arr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return arr[m - 1];
  }
}

class _YearButton extends StatelessWidget {
  final int year;
  final bool active;
  final VoidCallback onTap;

  const _YearButton({required this.year, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: active ? kMaroon : kDarkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? kMaroon : kDarkBorder),
          ),
          child: Text(
            '$year',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MonthChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? kMaroon : kDarkSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? kMaroon : kDarkBorder),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

/* ============================== VIEWS ============================== */

class _OverviewView extends StatelessWidget {
  final _ReportData data;
  const _OverviewView({required this.data});

  @override
  Widget build(BuildContext context) {
    return _ScrollArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderTitle(
            title: 'Laporan Keuangan',
            subtitle: 'Sumber: Transaksi & Produk (realtime)',
            trailing: _RightSummaryPills(
              total: data.totalRevenueLabel,
              tx: data.totalTransactions,
              margin: data.marginPct,
            ),
          ),
          const SizedBox(height: 12),
          const _TimeRangeRow(),
          const SizedBox(height: 14),
          _MetricListCard(
            items: [
              _MetricListItem(
                title: 'TOTAL PENDAPATAN',
                value: data.totalRevenueLabel,
                subtitle: '${data.totalTransactions} transaksi',
                accent: kMaroon,
                icon: Icons.payments_rounded,
              ),
              _MetricListItem(
                title: 'TOTAL BIAYA (HPP)',
                value: data.totalCostLabel,
                subtitle: 'Belum tersedia (model transaksi tidak menyimpan HPP)',
                accent: kSecondary,
                icon: Icons.trending_down_rounded,
              ),
              _MetricListItem(
                title: 'LABA BERSIH',
                value: data.netProfitLabel,
                subtitle: 'Margin ${data.marginPct}',
                accent: kMaroon,
                icon: Icons.show_chart_rounded,
              ),
              _MetricListItem(
                title: 'RATA-RATA TRANSAKSI',
                value: data.avgTicketLabel,
                subtitle: 'Per transaksi',
                accent: kTextMuted,
                icon: Icons.calculate_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceDashboardView extends StatelessWidget {
  final _ReportData data;
  const _FinanceDashboardView({required this.data});

  @override
  Widget build(BuildContext context) {
    return _ScrollArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeaderTitle(title: 'Performance Dashboard Finance'),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cols = w >= 1200 ? 3 : (w >= 900 ? 2 : 1);

              return _Grid(
                columns: cols,
                gap: 14,
                children: [
                  _MetricCard(
                    title: 'Kas Keluar',
                    value: data.cashOutLabel,
                    accent: kSecondary,
                    child: const _SparkLine(),
                  ),
                  _ChartCard(
                    title: 'Masuk vs Keluar',
                    child: Row(
                      children: [
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1.6,
                            child: _PieChartSimple(percentA: data.inRatio),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _LegendColumn(inRatio: data.inRatio),
                      ],
                    ),
                  ),
                  _MetricCard(
                    title: 'Saldo',
                    value: data.balanceLabel,
                    accent: kMaroon,
                    child: const _SparkLine(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cols = w >= 1200 ? 2 : 1;

              return _Grid(
                columns: cols,
                gap: 14,
                children: [
                  _ChartCard(
                    title: 'Kas Masuk',
                    subtitle: data.cashInLabel,
                    child: _MonthlyDotLine(),
                  ),
                  _ChartCard(
                    title: 'Transaksi (periode filter)',
                    subtitle: '${data.totalTransactions} transaksi',
                    child: _MiniBarStub(value: data.totalTransactions),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cols = w >= 1200 ? 3 : (w >= 900 ? 2 : 1);

              return _Grid(
                columns: cols,
                gap: 14,
                children: [
                  _MiniStatCard(
                    title: 'Penjualan Tertinggi (Harian)',
                    value: data.bestSalesLabel,
                    icon: Icons.trending_up_rounded,
                    accent: kMaroon,
                  ),
                  _MiniStatCard(
                    title: 'Penjualan Terendah (Harian)',
                    value: data.lowestSalesLabel,
                    icon: Icons.trending_down_rounded,
                    accent: kSecondary,
                  ),
                  _MiniStatCard(
                    title: 'Rata-rata Harian',
                    value: data.avgDailyLabel,
                    icon: Icons.show_chart_rounded,
                    accent: kTextMuted,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Top 5 Produk Terlaris',
            icon: Icons.emoji_events_rounded,
            child: data.topProducts.isEmpty
                ? Text(
              'Belum ada transaksi pada periode ini.',
              style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w800),
            )
                : Column(
              children: data.topProducts.take(5).toList().asMap().entries.map((e) {
                final idx = e.key + 1;
                final p = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RankRow(
                    rank: idx,
                    title: p.name,
                    subtitle: 'Terjual: ${p.sold} unit • SKU: ${p.sku}',
                    rightTop: p.revenueLabel,
                    rightBottom: '',
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProdukView extends StatelessWidget {
  final _ReportData data;
  const _ProdukView({required this.data});

  @override
  Widget build(BuildContext context) {
    return _ScrollArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderTitle(
            title: 'Laporan Produk',
            subtitle: 'Top produk dari agregasi item transaksi + stok menipis dari ProductService',
            trailing: _RightSummaryPills(
              total: data.totalRevenueLabel,
              tx: data.totalTransactions,
              margin: data.marginPct,
            ),
          ),
          const SizedBox(height: 12),
          const _TimeRangeRow(),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Top 10 Produk Terlaris',
            icon: Icons.emoji_events_rounded,
            child: data.topProducts.isEmpty
                ? Text(
              'Belum ada transaksi pada periode ini.',
              style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w800),
            )
                : Column(
              children: data.topProducts.take(10).toList().asMap().entries.map((e) {
                final idx = e.key + 1;
                final p = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RankRow(
                    rank: idx,
                    title: p.name,
                    subtitle: 'Terjual: ${p.sold} unit • SKU: ${p.sku}',
                    rightTop: p.revenueLabel,
                    rightBottom: '',
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Stok Menipis',
            icon: Icons.warning_amber_rounded,
            child: data.lowStocks.isEmpty
                ? Text(
              'Tidak ada stok menipis pada ambang saat ini.',
              style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w800),
            )
                : Column(
              children: data.lowStocks.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LowStockRow(
                    name: s.name,
                    remaining: s.remaining,
                    onRestock: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Restock ${s.name} (stub)')),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _KaryawanView extends StatelessWidget {
  final _ReportData data;
  const _KaryawanView({required this.data});

  @override
  Widget build(BuildContext context) {
    return _ScrollArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderTitle(
            title: 'Laporan Karyawan',
            subtitle:
            'Catatan: TransactionData belum menyimpan kasir/karyawan. Tab ini akurat jika Anda menambah field kasir.',
            trailing: _RightSummaryPills(
              total: data.totalRevenueLabel,
              tx: data.totalTransactions,
              margin: data.marginPct,
            ),
          ),
          const SizedBox(height: 12),
          const _TimeRangeRow(),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Top Performer (Placeholder)',
            icon: Icons.emoji_events_rounded,
            highlightBorder: kSecondary,
            child: Row(
              children: [
                _AvatarCircle(letter: 'K', bg: kSecondary, fg: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Semua Kasir',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.karyawanTopTitle,
                        style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.star_rounded, color: kMaroon, size: 28),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Cara mengaktifkan data karyawan (ringkas)',
            icon: Icons.info_outline_rounded,
            child: Text(
              'Tambahkan field cashierId/cashierName pada TransactionData saat transaksi dibuat, lalu agregasikan per kasir di Report.',
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================== REUSABLE UI ============================== */

class _HeaderTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _HeaderTitle({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 860;

        if (trailing == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w800)),
              ],
            ],
          );
        }

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w800)),
              ],
              const SizedBox(height: 10),
              trailing!,
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w800)),
                  ],
                ],
              ),
            ),
            trailing!,
          ],
        );
      },
    );
  }
}

class _ScrollArea extends StatelessWidget {
  final Widget child;
  const _ScrollArea({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? highlightBorder;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.highlightBorder,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = highlightBorder ?? kDarkBorder;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  final int columns;
  final double gap;
  final List<Widget> children;

  const _Grid({required this.columns, required this.gap, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += columns) {
      final rowChildren = children.skip(i).take(columns).toList();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int j = 0; j < rowChildren.length; j++) ...[
              Expanded(child: rowChildren[j]),
              if (j != rowChildren.length - 1) SizedBox(width: gap),
            ],
            if (rowChildren.length < columns)
              for (int k = 0; k < (columns - rowChildren.length); k++) ...[
                SizedBox(width: gap),
                const Expanded(child: SizedBox()),
              ],
          ],
        ),
      );
      rows.add(SizedBox(height: gap));
    }
    if (rows.isNotEmpty) rows.removeLast();
    return Column(children: rows);
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;
  final Widget child;

  const _MetricCard({required this.title, required this.value, required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDarkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 12),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: kDarkBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(0.22)),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _ChartCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDarkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w900)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          ],
          const SizedBox(height: 12),
          Container(
            height: 170,
            decoration: BoxDecoration(
              color: kDarkBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kDarkBorder),
            ),
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _MiniStatCard({required this.title, required this.value, required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDarkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: kDarkBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.22)),
              ),
              child: const _SparkLine(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final String rightTop;
  final String rightBottom;

  const _RankRow({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.rightTop,
    required this.rightBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kDarkBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkBorder),
      ),
      child: Row(
        children: [
          _RankBadge(rank: rank),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rightTop, style: const TextStyle(color: kMaroon, fontWeight: FontWeight.w900)),
              if (rightBottom.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(rightBottom, style: TextStyle(color: kSecondary, fontWeight: FontWeight.w900)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: kSecondary, borderRadius: BorderRadius.circular(10)),
      child: Center(
        child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

/* ============================== LOW STOCK ROW ============================== */

class _LowStockRow extends StatelessWidget {
  final String name;
  final int remaining;
  final VoidCallback onRestock;

  const _LowStockRow({required this.name, required this.remaining, required this.onRestock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kDarkBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kSecondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kSecondary.withOpacity(0.25)),
            ),
            child: Icon(Icons.warning_rounded, color: kSecondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('Sisa: $remaining unit', style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: onRestock,
              style: ElevatedButton.styleFrom(
                backgroundColor: kMaroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Restock', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================== OVERVIEW METRIC LIST ============================== */

class _MetricListCard extends StatelessWidget {
  final List<_MetricListItem> items;
  const _MetricListCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _MetricRowCard(item: e),
      ))
          .toList(),
    );
  }
}

class _MetricListItem {
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final IconData icon;

  _MetricListItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });
}

class _MetricRowCard extends StatelessWidget {
  final _MetricListItem item;
  const _MetricRowCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDarkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: item.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: item.accent.withOpacity(0.25)),
            ),
            child: Icon(item.icon, color: item.accent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w900, fontSize: 12)),
                const SizedBox(height: 4),
                Text(item.value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                const SizedBox(height: 2),
                Text(item.subtitle, style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================== SUMMARY PILLS (RESPONSIVE) ============================== */

class _RightSummaryPills extends StatelessWidget {
  final String total;
  final int tx;
  final String margin;

  const _RightSummaryPills({required this.total, required this.tx, required this.margin});

  @override
  Widget build(BuildContext context) {
    // Wrap agar tidak overflow di mobile/tablet
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        _SummaryPill(
          icon: Icons.payments_rounded,
          title: total,
          subtitle: 'TOTAL PENDAPATAN',
          accent: kMaroon,
        ),
        _TinyStatPill(label: '$tx', sub: 'TRANSAKSI'),
        _TinyStatPill(label: margin, sub: 'MARGIN'),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _SummaryPill({required this.icon, required this.title, required this.subtitle, required this.accent});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kDarkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kDarkBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.25)),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w800, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyStatPill extends StatelessWidget {
  final String label;
  final String sub;

  const _TinyStatPill({required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 110),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kDarkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kDarkBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w900, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/* ============================== TIME RANGE (UI ONLY) ============================== */

class _TimeRangeRow extends StatefulWidget {
  const _TimeRangeRow();

  @override
  State<_TimeRangeRow> createState() => _TimeRangeRowState();
}

class _TimeRangeRowState extends State<_TimeRangeRow> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Hari Ini', Icons.today_rounded),
      ('7 Hari', Icons.date_range_rounded),
      ('30 Hari', Icons.calendar_month_rounded),
      ('1 Tahun', Icons.schedule_rounded),
      ('Semua Data', Icons.all_inclusive_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkBorder),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(items.length, (i) {
          final active = i == selected;
          return _RangeChip(
            label: items[i].$1,
            icon: items[i].$2,
            active: active,
            onTap: () => setState(() => selected = i),
          );
        }),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _RangeChip({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = active ? kMaroon : kDarkBg;
    final border = active ? kMaroon : kDarkBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 110,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================== MINI CHARTS (NO DEPENDENCY) ============================== */

class _LegendColumn extends StatelessWidget {
  final double inRatio;
  const _LegendColumn({required this.inRatio});

  @override
  Widget build(BuildContext context) {
    final inPct = (inRatio * 100).round();
    final outPct = 100 - inPct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegendItem(color: kMaroon, text: '$inPct% Masuk'),
        const SizedBox(height: 10),
        _LegendItem(color: kTextMuted, text: '$outPct% Keluar'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _PieChartSimple extends StatelessWidget {
  final double percentA; // 0..1
  const _PieChartSimple({required this.percentA});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PiePainter(percentA: percentA),
      child: const SizedBox.expand(),
    );
  }
}

class _PiePainter extends CustomPainter {
  final double percentA;
  _PiePainter({required this.percentA});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide * 0.38);
    final rect = Rect.fromCircle(center: center, radius: r);

    final paintA = Paint()..color = kMaroon;
    final paintB = Paint()..color = kTextMuted;

    const start = -1.57079632679; // -pi/2
    final sweepA = 6.28318530718 * percentA; // 2pi
    final sweepB = 6.28318530718 - sweepA;

    canvas.drawArc(rect, start, sweepA, true, paintA);
    canvas.drawArc(rect, start + sweepA, sweepB, true, paintB);

    final ring = Paint()
      ..color = kDarkBg
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r * 0.55, ring);
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) => oldDelegate.percentA != percentA;
}

class _SparkLine extends StatelessWidget {
  const _SparkLine();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparkPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _SparkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(10, size.height * 0.65);
    path.cubicTo(
      size.width * 0.30,
      size.height * 0.35,
      size.width * 0.55,
      size.height * 0.80,
      size.width * 0.90,
      size.height * 0.40,
    );

    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MonthlyDotLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotLinePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _DotLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(10, size.height - 20), Offset(size.width - 10, size.height - 20), axis);

    final dotPaint = Paint()..color = kSecondary;
    final step = (size.width - 24) / 9;
    for (int i = 0; i < 10; i++) {
      canvas.drawCircle(Offset(12 + i * step, size.height - 20), 3.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniBarStub extends StatelessWidget {
  final int value;
  const _MiniBarStub({required this.value});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$value',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32),
      ),
    );
  }
}

/* ============================== AVATAR (KARYAWAN) ============================== */

class _AvatarCircle extends StatelessWidget {
  final String letter;
  final Color bg;
  final Color fg;
  const _AvatarCircle({required this.letter, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
        child: Text(letter, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
    );
  }
}

/* ============================== RUPIAH HELPERS ============================== */

String formatRupiahInt(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer();
  int count = 0;

  for (int i = s.length - 1; i >= 0; i--) {
    buf.write(s[i]);
    count++;
    if (count == 3 && i != 0) {
      buf.write('.');
      count = 0;
    }
  }

  final reversed = buf.toString().split('').reversed.join();
  final prefix = value < 0 ? '-Rp ' : 'Rp ';
  return '$prefix$reversed';
}
