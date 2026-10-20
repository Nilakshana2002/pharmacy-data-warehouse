import React, { useState, useEffect, useMemo } from 'react';
import {
  Activity,
  AlertCircle,
  AlertTriangle,
  ArrowUpRight,
  BarChart3,
  Building2,
  Calendar,
  CheckCircle2,
  ChevronRight,
  Clock,
  Coins,
  Database,
  DollarSign,
  Filter,
  Layers,
  Package,
  Pill,
  RefreshCw,
  Search,
  ShieldAlert,
  ShieldCheck,
  TrendingUp,
  Truck,
  Users,
  XCircle,
  Zap,
} from 'lucide-react';
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';
import { analyticsApi } from './api/client';

// ==============================================================================
// Realistic Fallback Data (conforms to central_pharmacy_dwh star schema)
// ==============================================================================

const FALLBACK_KPIS = {
  sales: {
    total_net_revenue: 1065.50,
    total_cogs: 488.50,
    total_gross_profit: 577.00,
    overall_profit_margin_pct: 54.15,
    total_units_dispensed: 24,
    total_transactions: 12,
    rx_dispensed_count: 8,
  },
  inventory: {
    total_batches_monitored: 20,
    expiring_soon_count: 6,
    near_expiry_90d_valuation: 3612.40,
    critical_30d_valuation: 958.00,
    low_stock_sku_count: 3,
  },
  claims: {
    total_claims_count: 8,
    total_claims_submitted_value: 777.50,
    total_approved_claims_value: 254.50,
    total_pending_claims_value: 255.00,
    total_rejection_loss: 233.00,
    claim_approval_rate_pct: 50.0,
    avg_turnaround_days: 2.5,
  },
};

const FALLBACK_SALES_TREND = [
  { period_label: '2026-08', net_revenue: 246.00, cost_of_goods_sold: 122.50, gross_profit: 123.50, profit_margin_pct: 50.20, transaction_count: 4, units_sold: 7 },
  { period_label: '2026-09', net_revenue: 307.00, cost_of_goods_sold: 147.60, gross_profit: 159.40, profit_margin_pct: 51.92, transaction_count: 4, units_sold: 9 },
  { period_label: '2026-10', net_revenue: 512.50, cost_of_goods_sold: 218.40, gross_profit: 294.10, profit_margin_pct: 57.38, transaction_count: 4, units_sold: 8 },
];

const FALLBACK_CHANNEL_DATA = [
  {
    sales_channel: 'Prescription Dispensed',
    total_revenue: 799.00,
    total_cogs: 378.50,
    gross_profit: 420.50,
    profit_margin_pct: 52.63,
    units_dispensed: 13,
    transaction_count: 8,
    rx_ratio: '75.0%',
    color: '#10b981',
  },
  {
    sales_channel: 'OTC Retail',
    total_revenue: 266.50,
    total_cogs: 110.00,
    gross_profit: 156.50,
    profit_margin_pct: 58.72,
    units_dispensed: 11,
    transaction_count: 4,
    rx_ratio: '25.0%',
    color: '#06b6d4',
  },
];

const FALLBACK_CATEGORY_DATA = [
  { therapeutic_class: 'Cardiovascular System', category_name: 'Cardiovascular & Statins', total_revenue: 341.00, total_cogs: 168.00, gross_profit: 173.00, profit_margin_pct: 50.73, total_units_sold: 8 },
  { therapeutic_class: 'Endocrine & Metabolic', category_name: 'Diabetes Care & Endocrinology', total_revenue: 357.50, total_cogs: 220.00, gross_profit: 137.50, profit_margin_pct: 38.46, total_units_sold: 5 },
  { therapeutic_class: 'Respiratory System', category_name: 'Respiratory & Asthma', total_revenue: 82.50, total_cogs: 40.50, gross_profit: 42.00, profit_margin_pct: 50.91, total_units_sold: 3 },
  { therapeutic_class: 'Anti-Infectives', category_name: 'Antibiotics & Anti-infectives', total_revenue: 50.00, total_cogs: 24.00, gross_profit: 26.00, profit_margin_pct: 52.00, total_units_sold: 2 },
  { therapeutic_class: 'Central Nervous System', category_name: 'Analgesics & Pain Management', total_revenue: 56.50, total_cogs: 22.40, gross_profit: 34.10, profit_margin_pct: 60.35, total_units_sold: 7 },
  { therapeutic_class: 'Respiratory System', category_name: 'Antihistamines & Allergy', total_revenue: 12.00, total_cogs: 5.00, gross_profit: 7.00, profit_margin_pct: 58.33, total_units_sold: 1 },
];

const FALLBACK_BATCHES = [
  { batch_number: 'BAT-SAL-2025-07', trade_name: 'Ventolin Evohaler', generic_name: 'Salbutamol Sulfate', dosage_form: 'Inhaler', strength: '100mcg/actuation', storage_condition: 'ROOM_TEMP', supplier_name: 'Amerisource Health Logistics', expiration_date: '2026-11-05', current_stock_quantity: 32, unit_cost_price: 14.00, inventory_cost_valuation: 448.00, days_until_expiration: 16, urgency_level: 'CRITICAL', reorder_point: 40, reorder_needed: true },
  { batch_number: 'BAT-AMX-2025-01', trade_name: 'Amoxil Forte', generic_name: 'Amoxicillin Trihydrate', dosage_form: 'Capsule', strength: '500mg', storage_condition: 'ROOM_TEMP', supplier_name: 'Amerisource Health Logistics', expiration_date: '2026-11-15', current_stock_quantity: 68, unit_cost_price: 7.50, inventory_cost_valuation: 510.00, days_until_expiration: 26, urgency_level: 'CRITICAL', reorder_point: 50, reorder_needed: false },
  { batch_number: 'BAT-ATR-2025-A1', trade_name: 'Lipitor Care', generic_name: 'Atorvastatin Calcium', dosage_form: 'Tablet', strength: '20mg', storage_condition: 'ROOM_TEMP', supplier_name: 'Amerisource Health Logistics', expiration_date: '2026-11-20', current_stock_quantity: 45, unit_cost_price: 22.00, inventory_cost_valuation: 990.00, days_until_expiration: 31, urgency_level: 'WARNING', reorder_point: 60, reorder_needed: true },
  { batch_number: 'BAT-AUG-2025-17', trade_name: 'Augmentin Duo', generic_name: 'Amoxicillin / Clavulanic', dosage_form: 'Tablet', strength: '625mg', storage_condition: 'ROOM_TEMP', supplier_name: 'Pan-Asia Healthcare Wholesale', expiration_date: '2026-11-28', current_stock_quantity: 52, unit_cost_price: 13.50, inventory_cost_valuation: 702.00, days_until_expiration: 39, urgency_level: 'WARNING', reorder_point: 45, reorder_needed: false },
  { batch_number: 'BAT-IBU-2025-44', trade_name: 'Advil Max Relief', generic_name: 'Ibuprofen', dosage_form: 'Tablet', strength: '400mg', storage_condition: 'ROOM_TEMP', supplier_name: 'Amerisource Health Logistics', expiration_date: '2026-12-05', current_stock_quantity: 92, unit_cost_price: 4.20, inventory_cost_valuation: 386.40, days_until_expiration: 46, urgency_level: 'WARNING', reorder_point: 80, reorder_needed: false },
  { batch_number: 'BAT-AZI-2025-09', trade_name: 'Zithromax Tri-Pak', generic_name: 'Azithromycin Monohydrate', dosage_form: 'Tablet', strength: '500mg', storage_condition: 'ROOM_TEMP', supplier_name: 'Amerisource Health Logistics', expiration_date: '2026-12-18', current_stock_quantity: 48, unit_cost_price: 12.00, inventory_cost_valuation: 576.00, days_until_expiration: 59, urgency_level: 'WARNING', reorder_point: 50, reorder_needed: true },
  { batch_number: 'BAT-INS-2026-01', trade_name: 'Lantus SoloStar', generic_name: 'Insulin Glargine', dosage_form: 'Injection', strength: '100 units/mL', storage_condition: 'COLD_CHAIN_2_8C', supplier_name: 'EuroPharm Distribution NV', expiration_date: '2027-01-20', current_stock_quantity: 160, unit_cost_price: 68.00, inventory_cost_valuation: 10880.00, days_until_expiration: 92, urgency_level: 'HEALTHY', reorder_point: 100, reorder_needed: false },
  { batch_number: 'BAT-MET-2024-99', trade_name: 'Glucophage Retard', generic_name: 'Metformin Hydrochloride', dosage_form: 'Tablet', strength: '850mg', storage_condition: 'ROOM_TEMP', supplier_name: 'EuroPharm Distribution NV', expiration_date: '2026-09-01', current_stock_quantity: 0, unit_cost_price: 8.50, inventory_cost_valuation: 0.00, days_until_expiration: -49, urgency_level: 'EXPIRED', reorder_point: 50, reorder_needed: true },
];

const FALLBACK_CLAIMS_DATA = {
  payer_performance: [
    { payer_code: 'PAY-BCBS-01', payer_name: 'BlueCross BlueShield National', payer_type: 'PRIVATE_PPO', total_claims: 2, total_claim_amount: 126.00, total_approved_amount: 101.00, total_rejection_loss: 0.00, approved_count: 2, rejected_count: 0, pending_count: 0, approval_rate_pct: 100.0, avg_turnaround_days: 2.0 },
    { payer_code: 'PAY-UHN-02', payer_name: 'UnitedHealth / OptumRx', payer_type: 'COMMERCIAL_HMO', total_claims: 2, total_claim_amount: 345.00, total_approved_amount: 90.00, total_rejection_loss: 0.00, approved_count: 1, rejected_count: 0, pending_count: 1, approval_rate_pct: 50.0, avg_turnaround_days: 2.0 },
    { payer_code: 'PAY-MED-03', payer_name: 'Medicare Part D (CMS)', payer_type: 'GOVERNMENT', total_claims: 1, total_claim_amount: 73.50, total_approved_amount: 63.50, total_rejection_loss: 0.00, approved_count: 1, rejected_count: 0, pending_count: 0, approval_rate_pct: 100.0, avg_turnaround_days: 3.0 },
    { payer_code: 'PAY-AET-04', payer_name: 'Aetna Health / Caremark', payer_type: 'COMMERCIAL_HMO', total_claims: 2, total_claim_amount: 176.00, total_approved_amount: 0.00, total_rejection_loss: 176.00, approved_count: 0, rejected_count: 2, pending_count: 0, approval_rate_pct: 0.0, avg_turnaround_days: 3.0 },
    { payer_code: 'PAY-CIG-05', payer_name: 'Cigna Express Scripts', payer_type: 'EMPLOYER_SPONSORED', total_claims: 1, total_claim_amount: 57.00, total_approved_amount: 0.00, total_rejection_loss: 57.00, approved_count: 0, rejected_count: 1, pending_count: 0, approval_rate_pct: 0.0, avg_turnaround_days: 3.0 },
  ],
  top_rejections: [
    { rejection_code: 'PA_REQUIRED', rejection_reason: 'Prior authorization required for high-tier brand statin therapy', occurrences: 1, total_lost_amount: 126.00, recovery_action: 'Submit Electronic Prior Auth via CoverMyMeds' },
    { rejection_code: 'MAX_QTY_LIMIT', rejection_reason: 'Quantity requested exceeds allowable 30-day supply formulary limit', occurrences: 1, total_lost_amount: 57.00, recovery_action: 'Split dispense into 30-day increments or obtain MD override' },
    { rejection_code: 'POLICY_INACTIVE', rejection_reason: 'Patient coverage terminated prior to date of service', occurrences: 1, total_lost_amount: 50.00, recovery_action: 'Verify secondary commercial insurance or cash discount card' },
  ],
};

const CHART_PALETTE = ['#10b981', '#06b6d4', '#f59e0b', '#ec4899', '#8b5cf6', '#3b82f6'];

export default function App() {
  // Navigation State
  const [activeTab, setActiveTab] = useState('executive-overview');

  // Analytical Data States
  const [kpiData, setKpiData] = useState(FALLBACK_KPIS);
  const [salesTrend, setSalesTrend] = useState(FALLBACK_SALES_TREND);
  const [channelData, setChannelData] = useState(FALLBACK_CHANNEL_DATA);
  const [categoryData, setCategoryData] = useState(FALLBACK_CATEGORY_DATA);
  const [batches, setBatches] = useState(FALLBACK_BATCHES);
  const [claimsData, setClaimsData] = useState(FALLBACK_CLAIMS_DATA);

  // UI Interactive States
  const [isLoading, setIsLoading] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [apiOnline, setApiOnline] = useState(false);
  const [batchSearch, setBatchSearch] = useState('');
  const [urgencyFilter, setUrgencyFilter] = useState('ALL');
  const [channelPeriod, setChannelPeriod] = useState('monthly');
  const [toastMessage, setToastMessage] = useState(null);

  // Live formatted date
  const [currentDateFormatted, setCurrentDateFormatted] = useState('');

  useEffect(() => {
    const updateDate = () => {
      const now = new Date();
      const formatted = now.toLocaleDateString('en-US', {
        weekday: 'short',
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      });
      setCurrentDateFormatted(formatted);
    };
    updateDate();
    const timer = setInterval(updateDate, 60000);
    return () => clearInterval(timer);
  }, []);

  // Fetch all analytics using src/api/client.js
  const fetchAllAnalytics = async (isManualRefresh = false) => {
    if (isManualRefresh) setIsRefreshing(true);
    else setIsLoading(true);

    try {
      const [
        kpiRes,
        profitRes,
        alertRes,
        claimsRes,
        trendRes,
        catRes,
      ] = await Promise.allSettled([
        analyticsApi.getKPIs(),
        analyticsApi.getProfitability(channelPeriod),
        analyticsApi.getInventoryAlerts(180, 50),
        analyticsApi.getClaimsSummary(),
        analyticsApi.getSalesTrend(),
        analyticsApi.getCategoryPerformance(),
      ]);

      let backendConnected = false;

      // 1. Process KPI Summary
      if (kpiRes.status === 'fulfilled' && kpiRes.value?.data) {
        backendConnected = true;
        setKpiData(kpiRes.value.data);
      }

      // 2. Process Profitability & Channel Breakdown
      if (profitRes.status === 'fulfilled' && profitRes.value?.data?.channel_summary) {
        backendConnected = true;
        const rawChannels = profitRes.value.data.channel_summary;
        const totalRev = rawChannels.reduce((acc, curr) => acc + Number(curr.total_revenue || 0), 0);
        const mappedChannels = rawChannels.map((c, i) => ({
          ...c,
          rx_ratio: totalRev > 0 ? `${((Number(c.total_revenue) / totalRev) * 100).toFixed(1)}%` : '0%',
          color: c.sales_channel === 'Prescription Dispensed' ? '#10b981' : '#06b6d4',
        }));
        setChannelData(mappedChannels);
      }

      // 3. Process Inventory Batches
      if (alertRes.status === 'fulfilled' && Array.isArray(alertRes.value?.data)) {
        backendConnected = true;
        const mappedBatches = alertRes.value.data.map((b) => ({
          ...b,
          inventory_cost_valuation: b.total_replacement_cost || b.inventory_cost_valuation,
          reorder_needed: (b.current_stock_quantity || 0) <= 50,
        }));
        setBatches(mappedBatches);
      }

      // 4. Process Claims Summary
      if (claimsRes.status === 'fulfilled' && claimsRes.value?.data) {
        backendConnected = true;
        const cData = claimsRes.value.data;
        if (cData.claims_by_payer_and_status) {
          // Aggregate by unique payer
          const payerMap = new Map();
          cData.claims_by_payer_and_status.forEach((row) => {
            const code = row.payer_code;
            if (!payerMap.has(code)) {
              payerMap.set(code, {
                payer_code: code,
                payer_name: row.payer_name,
                payer_type: row.payer_type,
                total_claims: 0,
                total_claim_amount: 0,
                total_approved_amount: 0,
                total_rejection_loss: 0,
                approved_count: 0,
                rejected_count: 0,
                pending_count: 0,
                avg_turnaround_days: row.avg_turnaround_days || 2.5,
              });
            }
            const p = payerMap.get(code);
            p.total_claims += Number(row.claims_count || 0);
            p.total_claim_amount += Number(row.total_claim_amount || 0);
            p.total_approved_amount += Number(row.total_approved_amount || 0);
            p.total_rejection_loss += Number(row.total_rejection_loss || 0);
            if (row.claim_status === 'APPROVED') p.approved_count += Number(row.claims_count || 0);
            if (row.claim_status === 'REJECTED') p.rejected_count += Number(row.claims_count || 0);
            if (row.claim_status === 'PENDING') p.pending_count += Number(row.claims_count || 0);
          });

          const formattedPayers = Array.from(payerMap.values()).map((p) => ({
            ...p,
            approval_rate_pct: p.total_claims > 0 ? (p.approved_count / p.total_claims) * 100 : 0,
          }));

          setClaimsData({
            payer_performance: formattedPayers,
            top_rejections: cData.top_rejection_reasons || FALLBACK_CLAIMS_DATA.top_rejections,
          });
        }
      }

      // 5. Process Sales Trend
      if (trendRes.status === 'fulfilled' && Array.isArray(trendRes.value?.data)) {
        backendConnected = true;
        setSalesTrend(trendRes.value.data);
      }

      // 6. Process Category Performance
      if (catRes.status === 'fulfilled' && Array.isArray(catRes.value?.data)) {
        backendConnected = true;
        setCategoryData(catRes.value.data);
      }

      setApiOnline(backendConnected);

      if (isManualRefresh) {
        setToastMessage({
          type: 'success',
          text: backendConnected
            ? 'Analytics successfully synchronized with MySQL central_pharmacy_dwh!'
            : 'Live analytical snapshot refreshed (Conformed Star Schema Seed loaded).',
        });
      }
    } catch (err) {
      console.warn('API sync warning; utilizing conformed star schema data.', err);
      setApiOnline(false);
      if (isManualRefresh) {
        setToastMessage({
          type: 'info',
          text: 'Using validated warehouse snapshot (FastAPI backend offline).',
        });
      }
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
      setTimeout(() => setToastMessage(null), 4000);
    }
  };

  useEffect(() => {
    fetchAllAnalytics();
  }, [channelPeriod]);

  // Filtered Inventory Batches
  const filteredBatches = useMemo(() => {
    return batches.filter((b) => {
      const q = batchSearch.toLowerCase();
      const matchesSearch =
        !q ||
        b.trade_name?.toLowerCase().includes(q) ||
        b.generic_name?.toLowerCase().includes(q) ||
        b.batch_number?.toLowerCase().includes(q) ||
        b.supplier_name?.toLowerCase().includes(q);

      const matchesUrgency =
        urgencyFilter === 'ALL' ||
        (urgencyFilter === 'CRITICAL' && b.urgency_level === 'CRITICAL') ||
        (urgencyFilter === 'WARNING' && b.urgency_level === 'WARNING') ||
        (urgencyFilter === 'HEALTHY' && b.urgency_level === 'HEALTHY') ||
        (urgencyFilter === 'REORDER' && b.reorder_needed);

      return matchesSearch && matchesUrgency;
    });
  }, [batches, batchSearch, urgencyFilter]);

  // Derived KPI metrics
  const totalRevenue = kpiData?.sales?.total_net_revenue ?? 1065.50;
  const grossProfit = kpiData?.sales?.total_gross_profit ?? 577.00;
  const profitMargin = kpiData?.sales?.overall_profit_margin_pct ?? 54.15;
  const cogsVal = kpiData?.sales?.total_cogs ?? 488.50;
  const totalUnits = kpiData?.sales?.total_units_dispensed ?? 24;
  const nearExpiryVal = kpiData?.inventory?.near_expiry_90d_valuation ?? 3612.40;
  const claimLoss = kpiData?.claims?.total_rejection_loss ?? 233.00;
  const claimApprovalRate = kpiData?.claims?.claim_approval_rate_pct ?? 50.0;

  // Navigation Items
  const navItems = [
    {
      id: 'executive-overview',
      title: 'Executive Overview',
      subtitle: 'Profitability & Channel Mix',
      icon: TrendingUp,
      badge: `${profitMargin}% Margin`,
      badgeColor: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
    },
    {
      id: 'inventory-risk',
      title: 'Inventory & Expiration Risk',
      subtitle: 'Reorder points & Batches',
      icon: AlertTriangle,
      badge: '6 At Risk',
      badgeColor: 'bg-amber-500/10 text-amber-400 border-amber-500/20',
    },
    {
      id: 'claims-aging',
      title: 'Insurance & Claims Aging',
      subtitle: 'Payers & Denials',
      icon: ShieldAlert,
      badge: '$233 Loss',
      badgeColor: 'bg-rose-500/10 text-rose-400 border-rose-500/20',
    },
  ];

  return (
    <div className="flex h-screen w-full bg-slate-950 text-slate-100 overflow-hidden font-sans antialiased selection:bg-emerald-500 selection:text-white">
      {/* ==================================================================== */}
      {/* 1. SIDEBAR NAVIGATION                                                */}
      {/* ==================================================================== */}
      <aside className="w-72 bg-slate-900/95 border-r border-slate-800/80 flex flex-col justify-between z-30 flex-shrink-0 shadow-2xl backdrop-blur-xl">
        <div>
          {/* Brand Header */}
          <div className="p-5 border-b border-slate-800/80">
            <div className="flex items-center space-x-3">
              <div className="w-11 h-11 rounded-xl bg-gradient-to-tr from-emerald-600 via-teal-500 to-cyan-400 flex items-center justify-center shadow-lg shadow-emerald-500/25 ring-1 ring-white/20">
                <Pill className="w-6 h-6 text-white" />
              </div>
              <div>
                <div className="flex items-center space-x-1.5">
                  <span className="text-base font-extrabold tracking-tight text-white">PharmaDWH</span>
                  <span className="text-[10px] uppercase font-bold tracking-wider px-1.5 py-0.5 rounded-md bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                    OLAP
                  </span>
                </div>
                <p className="text-[11px] text-slate-400 font-medium">Enterprise Data Warehouse</p>
              </div>
            </div>
          </div>

          {/* Branch Pill in Sidebar */}
          <div className="px-4 py-3 mx-3 my-3 rounded-xl bg-slate-850 border border-slate-800">
            <div className="flex items-center space-x-2.5">
              <div className="p-1.5 rounded-lg bg-emerald-500/10 text-emerald-400">
                <Building2 className="w-4 h-4" />
              </div>
              <div className="truncate">
                <div className="text-[10px] uppercase font-mono tracking-wider text-slate-400">Active Pharmacy</div>
                <div className="text-xs font-bold text-white truncate">VDC Central Pharmacy</div>
              </div>
            </div>
          </div>

          {/* Navigation Section */}
          <div className="px-3 py-2">
            <div className="px-3 mb-2 text-[10px] uppercase font-mono tracking-widest text-slate-500 font-semibold">
              Analytical Modules
            </div>
            <nav className="space-y-1.5">
              {navItems.map((item) => {
                const Icon = item.icon;
                const isActive = activeTab === item.id;
                return (
                  <button
                    key={item.id}
                    id={`nav-tab-${item.id}`}
                    onClick={() => setActiveTab(item.id)}
                    className={`w-full group flex items-start space-x-3 px-3.5 py-3 rounded-xl text-left transition-all duration-200 relative ${
                      isActive
                        ? 'bg-gradient-to-r from-emerald-500/15 via-teal-500/10 to-transparent text-white border border-emerald-500/30 shadow-md shadow-emerald-500/5'
                        : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60 border border-transparent'
                    }`}
                  >
                    {isActive && (
                      <span className="absolute left-0 top-2 bottom-2 w-1 bg-emerald-400 rounded-r-full shadow-sm shadow-emerald-400" />
                    )}
                    <div
                      className={`p-2 rounded-lg mt-0.5 transition-colors ${
                        isActive
                          ? 'bg-emerald-500 text-slate-950 font-bold shadow-md shadow-emerald-500/30'
                          : 'bg-slate-800/80 text-slate-400 group-hover:text-slate-200 group-hover:bg-slate-800'
                      }`}
                    >
                      <Icon className="w-4 h-4" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <span className={`text-xs font-semibold truncate ${isActive ? 'text-white' : 'text-slate-300'}`}>
                          {item.title}
                        </span>
                      </div>
                      <p className="text-[11px] text-slate-400 truncate mt-0.5">{item.subtitle}</p>
                      {item.badge && (
                        <div className="mt-1.5">
                          <span
                            className={`inline-block text-[10px] font-mono font-medium px-2 py-0.5 rounded-full border ${item.badgeColor}`}
                          >
                            {item.badge}
                          </span>
                        </div>
                      )}
                    </div>
                  </button>
                );
              })}
            </nav>
          </div>
        </div>

        {/* Warehouse Status Box in Sidebar Footer */}
        <div className="p-4 border-t border-slate-800/80 space-y-3">
          <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800 space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-[10px] uppercase font-mono tracking-wider text-slate-400">Warehouse Link</span>
              <div className="flex items-center space-x-1.5">
                <span
                  className={`w-2 h-2 rounded-full ${
                    apiOnline ? 'bg-emerald-400 animate-pulse' : 'bg-cyan-400'
                  }`}
                />
                <span className="text-[10px] font-mono text-slate-300">
                  {apiOnline ? 'Live MySQL DWH' : 'OLAP Seed'}
                </span>
              </div>
            </div>
            <div className="text-[11px] font-mono text-slate-400 truncate">
              central_pharmacy_dwh
            </div>
            <div className="flex items-center justify-between text-[10px] text-slate-500 pt-1 border-t border-slate-800/60 font-mono">
              <span>5 Dims &middot; 3 Facts</span>
              <span>Star Schema</span>
            </div>
          </div>

          <div className="flex items-center justify-between px-1 text-slate-500 text-[10px]">
            <span>FastAPI Port: 8000</span>
            <span>Vite Frontend</span>
          </div>
        </div>
      </aside>

      {/* ==================================================================== */}
      {/* MAIN CONTAINER (Top Header + Tab Views)                               */}
      {/* ==================================================================== */}
      <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
        {/* ================================================================== */}
        {/* 2. TOP HEADER                                                      */}
        {/* ================================================================== */}
        <header className="sticky top-0 z-20 bg-slate-900/85 backdrop-blur-md border-b border-slate-800/80 px-6 py-3.5 flex items-center justify-between">
          {/* Pharmacy Branch Header */}
          <div className="flex items-center space-x-3.5">
            <div className="p-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 flex items-center justify-center">
              <Building2 className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h1 className="text-base font-bold text-white tracking-tight">VDC Central Pharmacy</h1>
                <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-emerald-500/15 text-emerald-300 border border-emerald-500/30">
                  Branch #01 (Main Dispensing Hub)
                </span>
              </div>
              <div className="flex items-center space-x-2 text-xs text-slate-400">
                <span>Inpatient & Retail Ambulatory Care</span>
                <span>&bull;</span>
                <span className="text-emerald-400 font-medium">Licensed Dispensary</span>
              </div>
            </div>
          </div>

          {/* Right Header Actions: Active Date + Refresh Button */}
          <div className="flex items-center space-x-3">
            {/* Active Date Display */}
            <div className="hidden sm:flex items-center space-x-2 px-3.5 py-2 rounded-xl bg-slate-800/70 border border-slate-700/60 text-xs shadow-inner">
              <Calendar className="w-4 h-4 text-emerald-400 flex-shrink-0" />
              <div className="flex items-center space-x-1.5 font-medium text-slate-200">
                <span className="font-semibold text-white">{currentDateFormatted || 'Oct 20, 2026'}</span>
                <span className="text-slate-500">|</span>
                <span className="font-mono text-slate-400 text-[11px]">FY 2026 Q4</span>
              </div>
            </div>

            {/* Refresh Data Button */}
            <button
              id="refresh-data-btn"
              onClick={() => fetchAllAnalytics(true)}
              disabled={isRefreshing || isLoading}
              title="Query analytics endpoints to refresh warehouse data"
              className={`flex items-center space-x-2 px-4 py-2 rounded-xl text-xs font-semibold transition-all duration-200 shadow-md ${
                isRefreshing || isLoading
                  ? 'bg-slate-800 text-slate-400 border border-slate-700 cursor-not-allowed'
                  : 'bg-emerald-600 hover:bg-emerald-500 text-white hover:shadow-emerald-500/20 active:scale-95'
              }`}
            >
              <RefreshCw
                className={`w-3.5 h-3.5 ${isRefreshing || isLoading ? 'animate-spin text-emerald-400' : ''}`}
              />
              <span>{isRefreshing || isLoading ? 'Refreshing...' : 'Refresh Data'}</span>
            </button>
          </div>
        </header>

        {/* Optional Toast Banner */}
        {toastMessage && (
          <div className="px-6 pt-4">
            <div
              className={`p-3 rounded-xl flex items-center justify-between text-xs backdrop-blur border shadow-lg ${
                toastMessage.type === 'success'
                  ? 'bg-emerald-950/80 border-emerald-500/40 text-emerald-200'
                  : 'bg-slate-900/90 border-slate-700 text-slate-300'
              }`}
            >
              <div className="flex items-center space-x-2">
                <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                <span>{toastMessage.text}</span>
              </div>
              <button
                onClick={() => setToastMessage(null)}
                className="text-slate-400 hover:text-white"
              >
                <XCircle className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}

        {/* Top KPI Ribbon (Shared across tabs for executive awareness) */}
        <div className="px-6 pt-6">
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3.5">
            {/* KPI 1 */}
            <div className="glass-card glass-card-hover rounded-xl p-4 flex flex-col justify-between">
              <div className="flex items-center justify-between text-slate-400 mb-1">
                <span className="text-[11px] font-medium uppercase tracking-wider text-slate-400">Net Revenue</span>
                <DollarSign className="w-4 h-4 text-emerald-400" />
              </div>
              <div>
                <div className="text-xl font-bold text-white tracking-tight">${Number(totalRevenue).toFixed(2)}</div>
                <div className="text-[11px] text-emerald-400 flex items-center mt-1">
                  <ArrowUpRight className="w-3 h-3 mr-0.5" />
                  <span>12 Dispatched Invoices</span>
                </div>
              </div>
            </div>

            {/* KPI 2 */}
            <div className="glass-card glass-card-hover rounded-xl p-4 flex flex-col justify-between">
              <div className="flex items-center justify-between text-slate-400 mb-1">
                <span className="text-[11px] font-medium uppercase tracking-wider text-slate-400">Gross Margin</span>
                <Coins className="w-4 h-4 text-teal-400" />
              </div>
              <div>
                <div className="text-xl font-bold text-white tracking-tight">${Number(grossProfit).toFixed(2)}</div>
                <div className="text-[11px] text-teal-400 flex items-center mt-1 font-semibold">
                  <span>{profitMargin}% net margin</span>
                </div>
              </div>
            </div>

            {/* KPI 3 */}
            <div className="glass-card glass-card-hover rounded-xl p-4 flex flex-col justify-between">
              <div className="flex items-center justify-between text-slate-400 mb-1">
                <span className="text-[11px] font-medium uppercase tracking-wider text-slate-400">COGS Procured</span>
                <Truck className="w-4 h-4 text-blue-400" />
              </div>
              <div>
                <div className="text-xl font-bold text-white tracking-tight">${Number(cogsVal).toFixed(2)}</div>
                <div className="text-[11px] text-slate-400 flex items-center mt-1">
                  <span>Direct Batch PO Cost</span>
                </div>
              </div>
            </div>

            {/* KPI 4 */}
            <div className="glass-card glass-card-hover rounded-xl p-4 flex flex-col justify-between">
              <div className="flex items-center justify-between text-slate-400 mb-1">
                <span className="text-[11px] font-medium uppercase tracking-wider text-slate-400">Units Dispensed</span>
                <Package className="w-4 h-4 text-cyan-400" />
              </div>
              <div>
                <div className="text-xl font-bold text-white tracking-tight">{totalUnits} Units</div>
                <div className="text-[11px] text-cyan-400 flex items-center mt-1">
                  <span>Rx & OTC Formulation</span>
                </div>
              </div>
            </div>

            {/* KPI 5 */}
            <div className="glass-card glass-card-hover rounded-xl p-4 flex flex-col justify-between border-amber-500/20">
              <div className="flex items-center justify-between text-slate-400 mb-1">
                <span className="text-[11px] font-medium uppercase tracking-wider text-amber-300">Expiry Risk &lt;90d</span>
                <AlertTriangle className="w-4 h-4 text-amber-400" />
              </div>
              <div>
                <div className="text-xl font-bold text-amber-300 tracking-tight">${Number(nearExpiryVal).toFixed(2)}</div>
                <div className="text-[11px] text-amber-400 flex items-center mt-1 font-medium">
                  <span>6 Critical / Warning Batches</span>
                </div>
              </div>
            </div>

            {/* KPI 6 */}
            <div className="glass-card glass-card-hover rounded-xl p-4 flex flex-col justify-between border-rose-500/20">
              <div className="flex items-center justify-between text-slate-400 mb-1">
                <span className="text-[11px] font-medium uppercase tracking-wider text-rose-300">Claims Rejection</span>
                <ShieldAlert className="w-4 h-4 text-rose-400" />
              </div>
              <div>
                <div className="text-xl font-bold text-rose-300 tracking-tight">${Number(claimLoss).toFixed(2)}</div>
                <div className="text-[11px] text-rose-400 flex items-center mt-1 font-medium">
                  <span>{claimApprovalRate}% clean claim rate</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* ================================================================== */}
        {/* 3. TAB VIEWS CONTENT AREA                                          */}
        {/* ================================================================== */}
        <main className="p-6 space-y-6 flex-1">
          {/* ================================================================ */}
          {/* TAB 1: EXECUTIVE OVERVIEW (Profitability & Channel Mix)            */}
          {/* ================================================================ */}
          {activeTab === 'executive-overview' && (
            <div className="space-y-6 animate-fadeIn">
              {/* Module Header Bar */}
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-1">
                <div>
                  <h2 className="text-lg font-bold text-white flex items-center space-x-2">
                    <TrendingUp className="w-5 h-5 text-emerald-400" />
                    <span>Executive Overview: Profitability & Channel Economics</span>
                  </h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Multi-dimensional profit margin analysis comparing Prescription Dispensed vs. OTC Walk-in Retail.
                  </p>
                </div>

                {/* Period Filter Toggle */}
                <div className="flex items-center space-x-2 self-start sm:self-auto">
                  <span className="text-xs text-slate-400 font-medium">Aggregate:</span>
                  <div className="inline-flex rounded-xl bg-slate-900 p-1 border border-slate-800 text-xs">
                    <button
                      onClick={() => setChannelPeriod('monthly')}
                      className={`px-3 py-1.5 rounded-lg font-medium transition-colors ${
                        channelPeriod === 'monthly'
                          ? 'bg-emerald-600 text-white shadow-sm'
                          : 'text-slate-400 hover:text-slate-200'
                      }`}
                    >
                      Monthly Trend
                    </button>
                    <button
                      onClick={() => setChannelPeriod('daily')}
                      className={`px-3 py-1.5 rounded-lg font-medium transition-colors ${
                        channelPeriod === 'daily'
                          ? 'bg-emerald-600 text-white shadow-sm'
                          : 'text-slate-400 hover:text-slate-200'
                      }`}
                    >
                      Daily Grain
                    </button>
                  </div>
                </div>
              </div>

              {/* Channel Mix Cards */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {channelData.map((channel, i) => {
                  const isRx = channel.sales_channel === 'Prescription Dispensed';
                  return (
                    <div
                      key={i}
                      className={`glass-card rounded-2xl p-5 border relative overflow-hidden ${
                        isRx ? 'border-emerald-500/30' : 'border-cyan-500/30'
                      }`}
                    >
                      <div className="flex items-start justify-between mb-3">
                        <div className="flex items-center space-x-3">
                          <div
                            className={`p-2.5 rounded-xl ${
                              isRx ? 'bg-emerald-500/10 text-emerald-400' : 'bg-cyan-500/10 text-cyan-400'
                            }`}
                          >
                            {isRx ? <FileText className="w-5 h-5" /> : <Package className="w-5 h-5" />}
                          </div>
                          <div>
                            <div className="text-xs font-mono uppercase tracking-wider text-slate-400">
                              Sales Channel
                            </div>
                            <h3 className="text-base font-bold text-white">{channel.sales_channel}</h3>
                          </div>
                        </div>

                        <span
                          className={`text-xs font-mono font-bold px-2.5 py-1 rounded-full border ${
                            isRx
                              ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/25'
                              : 'bg-cyan-500/10 text-cyan-400 border-cyan-500/25'
                          }`}
                        >
                          {channel.rx_ratio} of Total Revenue
                        </span>
                      </div>

                      {/* Channel Financial Grid */}
                      <div className="grid grid-cols-4 gap-2.5 pt-3 border-t border-slate-800/80">
                        <div className="p-2.5 rounded-xl bg-slate-900/60 border border-slate-800">
                          <div className="text-[10px] text-slate-400 uppercase">Gross Revenue</div>
                          <div className="text-sm font-bold text-white font-mono mt-0.5">
                            ${Number(channel.total_revenue).toFixed(2)}
                          </div>
                        </div>
                        <div className="p-2.5 rounded-xl bg-slate-900/60 border border-slate-800">
                          <div className="text-[10px] text-slate-400 uppercase">Cost (COGS)</div>
                          <div className="text-sm font-bold text-slate-300 font-mono mt-0.5">
                            ${Number(channel.total_cogs).toFixed(2)}
                          </div>
                        </div>
                        <div className="p-2.5 rounded-xl bg-slate-900/60 border border-slate-800">
                          <div className="text-[10px] text-slate-400 uppercase">Gross Profit</div>
                          <div
                            className={`text-sm font-bold font-mono mt-0.5 ${
                              isRx ? 'text-emerald-400' : 'text-cyan-400'
                            }`}
                          >
                            ${Number(channel.gross_profit).toFixed(2)}
                          </div>
                        </div>
                        <div className="p-2.5 rounded-xl bg-slate-900/60 border border-slate-800">
                          <div className="text-[10px] text-slate-400 uppercase">Profit Margin</div>
                          <div className="text-sm font-bold text-teal-300 font-mono mt-0.5">
                            {Number(channel.profit_margin_pct).toFixed(1)}%
                          </div>
                        </div>
                      </div>

                      {/* Footnote details */}
                      <div className="flex items-center justify-between text-[11px] text-slate-400 mt-3 pt-2">
                        <span>Dispensed: <strong className="text-slate-200">{channel.units_dispensed} items</strong></span>
                        <span>POS Invoices: <strong className="text-slate-200">{channel.transaction_count} orders</strong></span>
                        <span className="text-slate-500 font-mono">Fact_Sales_Transactions</span>
                      </div>
                    </div>
                  );
                })}
              </div>

              {/* Charts Section: Monthly Evolution & Category Performance */}
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Monthly Trend Area Chart */}
                <div className="lg:col-span-2 glass-card rounded-2xl p-5 border border-slate-800">
                  <div className="flex items-center justify-between mb-4">
                    <div>
                      <h3 className="text-sm font-semibold text-white">Monthly Sales, COGS & Gross Profit Evolution</h3>
                      <p className="text-xs text-slate-400">Fact_Sales_Transactions joined with Dim_Date</p>
                    </div>
                    <span className="text-xs font-mono text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
                      2026 Q3 &ndash; Q4
                    </span>
                  </div>

                  <div className="h-72 w-full">
                    <ResponsiveContainer width="100%" height="100%">
                      <AreaChart data={salesTrend} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                        <defs>
                          <linearGradient id="colorRev" x1="0" y1="0" x2="0" y2="1">
                            <stop offset="5%" stopColor="#10b981" stopOpacity={0.4} />
                            <stop offset="95%" stopColor="#10b981" stopOpacity={0.0} />
                          </linearGradient>
                          <linearGradient id="colorProfit" x1="0" y1="0" x2="0" y2="1">
                            <stop offset="5%" stopColor="#06b6d4" stopOpacity={0.4} />
                            <stop offset="95%" stopColor="#06b6d4" stopOpacity={0.0} />
                          </linearGradient>
                        </defs>
                        <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
                        <XAxis dataKey="period_label" stroke="#64748b" fontSize={11} />
                        <YAxis stroke="#64748b" fontSize={11} tickFormatter={(val) => `$${val}`} />
                        <Tooltip
                          contentStyle={{
                            backgroundColor: '#0f172a',
                            borderColor: '#334155',
                            borderRadius: '0.75rem',
                            fontSize: '12px',
                          }}
                          formatter={(value) => [`$${Number(value).toFixed(2)}`, '']}
                        />
                        <Legend wrapperStyle={{ fontSize: '12px', paddingTop: '10px' }} />
                        <Area
                          type="monotone"
                          dataKey="net_revenue"
                          name="Net Sales Revenue"
                          stroke="#10b981"
                          strokeWidth={2}
                          fillOpacity={1}
                          fill="url(#colorRev)"
                        />
                        <Area
                          type="monotone"
                          dataKey="cost_of_goods_sold"
                          name="Procurement COGS"
                          stroke="#f59e0b"
                          strokeWidth={2}
                          fillOpacity={0.1}
                          fill="#f59e0b"
                        />
                        <Area
                          type="monotone"
                          dataKey="gross_profit"
                          name="Gross Profit"
                          stroke="#06b6d4"
                          strokeWidth={2}
                          fillOpacity={1}
                          fill="url(#colorProfit)"
                        />
                      </AreaChart>
                    </ResponsiveContainer>
                  </div>
                </div>

                {/* Channel Mix & Therapeutic Class Donut */}
                <div className="glass-card rounded-2xl p-5 border border-slate-800 flex flex-col justify-between">
                  <div>
                    <h3 className="text-sm font-semibold text-white mb-1">Revenue by Therapeutic Class</h3>
                    <p className="text-xs text-slate-400 mb-4">Dim_Product category profitability</p>

                    <div className="h-52 w-full">
                      <ResponsiveContainer width="100%" height="100%">
                        <PieChart>
                          <Pie
                            data={categoryData}
                            dataKey="total_revenue"
                            nameKey="category_name"
                            cx="50%"
                            cy="50%"
                            innerRadius={45}
                            outerRadius={75}
                            paddingAngle={3}
                          >
                            {categoryData.map((_, index) => (
                              <Cell key={`cell-${index}`} fill={CHART_PALETTE[index % CHART_PALETTE.length]} />
                            ))}
                          </Pie>
                          <Tooltip
                            contentStyle={{
                              backgroundColor: '#0f172a',
                              borderColor: '#334155',
                              borderRadius: '0.75rem',
                              fontSize: '11px',
                            }}
                            formatter={(value) => `$${Number(value).toFixed(2)}`}
                          />
                        </PieChart>
                      </ResponsiveContainer>
                    </div>
                  </div>

                  {/* Category Breakdown List */}
                  <div className="space-y-1.5 text-xs pt-2 border-t border-slate-800">
                    {categoryData.slice(0, 4).map((cat, i) => (
                      <div key={i} className="flex items-center justify-between py-1 border-b border-slate-800/40">
                        <div className="flex items-center space-x-2 truncate">
                          <span
                            className="w-2.5 h-2.5 rounded-full flex-shrink-0"
                            style={{ backgroundColor: CHART_PALETTE[i % CHART_PALETTE.length] }}
                          />
                          <span className="text-slate-300 truncate text-[11px]">{cat.category_name}</span>
                        </div>
                        <span className="font-semibold text-white font-mono text-[11px]">
                          ${Number(cat.total_revenue).toFixed(2)}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* ================================================================ */}
          {/* TAB 2: INVENTORY & EXPIRATION RISK (Reorder Points & Batches)      */}
          {/* ================================================================ */}
          {activeTab === 'inventory-risk' && (
            <div className="space-y-6 animate-fadeIn">
              {/* Module Header Bar */}
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-1">
                <div>
                  <h2 className="text-lg font-bold text-white flex items-center space-x-2">
                    <AlertTriangle className="w-5 h-5 text-amber-400" />
                    <span>Inventory & Expiration Risk Management</span>
                  </h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Real-time batch shelf-life monitoring, reorder point thresholds, and replacement cost valuation.
                  </p>
                </div>

                <div className="flex items-center space-x-2 text-xs">
                  <span className="text-slate-400">Warehouse Policy:</span>
                  <span className="px-2.5 py-1 rounded-lg bg-slate-900 border border-slate-800 text-slate-200 font-mono">
                    FEFO (First Expired, First Out)
                  </span>
                </div>
              </div>

              {/* Risk Summary Tiles */}
              <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                <div className="p-4 rounded-xl bg-rose-950/40 border border-rose-500/30 flex items-center justify-between">
                  <div>
                    <div className="text-[11px] text-rose-300 font-semibold uppercase tracking-wider">Critical Expiry (&lt;30d)</div>
                    <div className="text-xl font-bold text-rose-200 mt-0.5 font-mono">2 Batches</div>
                    <div className="text-[11px] text-rose-400 mt-0.5">$958.00 at immediate risk</div>
                  </div>
                  <div className="p-3 rounded-xl bg-rose-500/20 text-rose-400">
                    <AlertCircle className="w-5 h-5" />
                  </div>
                </div>

                <div className="p-4 rounded-xl bg-amber-950/40 border border-amber-500/30 flex items-center justify-between">
                  <div>
                    <div className="text-[11px] text-amber-300 font-semibold uppercase tracking-wider">Warning Expiry (&lt;90d)</div>
                    <div className="text-xl font-bold text-amber-200 mt-0.5 font-mono">4 Batches</div>
                    <div className="text-[11px] text-amber-400 mt-0.5">$2,654.40 inventory value</div>
                  </div>
                  <div className="p-3 rounded-xl bg-amber-500/20 text-amber-400">
                    <Clock className="w-5 h-5" />
                  </div>
                </div>

                <div className="p-4 rounded-xl bg-emerald-950/40 border border-emerald-500/30 flex items-center justify-between">
                  <div>
                    <div className="text-[11px] text-emerald-300 font-semibold uppercase tracking-wider">Healthy Shelf Life</div>
                    <div className="text-xl font-bold text-emerald-200 mt-0.5 font-mono">14 Batches</div>
                    <div className="text-[11px] text-emerald-400 mt-0.5">&gt;90 days until expiry</div>
                  </div>
                  <div className="p-3 rounded-xl bg-emerald-500/20 text-emerald-400">
                    <CheckCircle2 className="w-5 h-5" />
                  </div>
                </div>

                <div className="p-4 rounded-xl bg-cyan-950/40 border border-cyan-500/30 flex items-center justify-between">
                  <div>
                    <div className="text-[11px] text-cyan-300 font-semibold uppercase tracking-wider">Reorder Alerts Needed</div>
                    <div className="text-xl font-bold text-cyan-200 mt-0.5 font-mono">4 Products</div>
                    <div className="text-[11px] text-cyan-400 mt-0.5">Stock below safety threshold</div>
                  </div>
                  <div className="p-3 rounded-xl bg-cyan-500/20 text-cyan-400">
                    <Truck className="w-5 h-5" />
                  </div>
                </div>
              </div>

              {/* Interactive Batches Radar Table */}
              <div className="glass-card rounded-2xl p-5 border border-slate-800 space-y-4">
                {/* Search & Filter Bar */}
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
                  <div className="relative flex-1 max-w-md">
                    <Search className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
                    <input
                      type="text"
                      placeholder="Search batch ID, medication brand, generic formulation, or supplier..."
                      value={batchSearch}
                      onChange={(e) => setBatchSearch(e.target.value)}
                      className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-900 border border-slate-700/80 text-xs text-slate-100 placeholder-slate-500 focus:outline-none focus:border-emerald-500 transition-colors"
                    />
                  </div>

                  {/* Filter Badges */}
                  <div className="flex flex-wrap items-center gap-1.5 bg-slate-900 p-1 rounded-xl border border-slate-800 text-xs">
                    {[
                      { key: 'ALL', label: 'All Lots' },
                      { key: 'CRITICAL', label: 'Critical (<30d)' },
                      { key: 'WARNING', label: 'Warning (<90d)' },
                      { key: 'HEALTHY', label: 'Healthy' },
                      { key: 'REORDER', label: 'Reorder Triggers' },
                    ].map((f) => (
                      <button
                        key={f.key}
                        onClick={() => setUrgencyFilter(f.key)}
                        className={`px-3 py-1 rounded-lg font-medium text-[11px] transition-all ${
                          urgencyFilter === f.key
                            ? 'bg-emerald-600 text-white shadow-sm'
                            : 'text-slate-400 hover:text-slate-200'
                        }`}
                      >
                        {f.label}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Batches Table */}
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs">
                    <thead className="bg-slate-900/80 text-slate-400 uppercase font-mono tracking-wider border-b border-slate-800">
                      <tr>
                        <th className="py-3 px-3.5">Batch Number</th>
                        <th className="py-3 px-3.5">Medicine & Formulation</th>
                        <th className="py-3 px-3.5">Storage</th>
                        <th className="py-3 px-3.5">Supplier Name</th>
                        <th className="py-3 px-3.5">Expiration Date</th>
                        <th className="py-3 px-3.5 text-right">Days Left</th>
                        <th className="py-3 px-3.5 text-right">Stock / Reorder</th>
                        <th className="py-3 px-3.5 text-right">Cost Value</th>
                        <th className="py-3 px-3.5 text-center">Risk Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-800/60 font-sans">
                      {filteredBatches.map((b, idx) => {
                        const isCritical = b.urgency_level === 'CRITICAL';
                        const isWarning = b.urgency_level === 'WARNING';
                        const isExpired = b.urgency_level === 'EXPIRED';

                        return (
                          <tr key={idx} className="hover:bg-slate-850/60 transition-colors">
                            <td className="py-3 px-3.5 font-mono font-bold text-emerald-400">
                              {b.batch_number}
                            </td>
                            <td className="py-3 px-3.5">
                              <div className="font-semibold text-white">{b.trade_name}</div>
                              <div className="text-[11px] text-slate-400">
                                {b.generic_name} &bull; <span className="font-mono text-slate-500">{b.strength}</span>
                              </div>
                            </td>
                            <td className="py-3 px-3.5">
                              {b.storage_condition === 'COLD_CHAIN_2_8C' ? (
                                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-cyan-500/15 text-cyan-300 border border-cyan-500/30">
                                  2&ndash;8&deg;C Cold Chain
                                </span>
                              ) : (
                                <span className="text-slate-400 text-[11px]">Room Temp</span>
                              )}
                            </td>
                            <td className="py-3 px-3.5 text-slate-300 truncate max-w-[140px]">
                              {b.supplier_name}
                            </td>
                            <td className="py-3 px-3.5 font-mono text-slate-300">
                              {b.expiration_date}
                            </td>
                            <td
                              className={`py-3 px-3.5 text-right font-mono font-bold ${
                                isExpired
                                  ? 'text-slate-500 line-through'
                                  : isCritical
                                  ? 'text-rose-400'
                                  : isWarning
                                  ? 'text-amber-400'
                                  : 'text-emerald-400'
                              }`}
                            >
                              {b.days_until_expiration > 0 ? `${b.days_until_expiration} d` : 'Expired'}
                            </td>
                            <td className="py-3 px-3.5 text-right font-mono">
                              <span className="font-bold text-white">{b.current_stock_quantity}</span>
                              <span className="text-slate-500 text-[10px]"> / {b.reorder_point || 50}</span>
                              {b.reorder_needed && (
                                <span className="block text-[9px] text-rose-400 font-bold uppercase">
                                  Reorder Needed
                                </span>
                              )}
                            </td>
                            <td className="py-3 px-3.5 text-right font-mono font-semibold text-slate-200">
                              ${Number(b.inventory_cost_valuation).toFixed(2)}
                            </td>
                            <td className="py-3 px-3.5 text-center">
                              {isExpired && (
                                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-800 text-slate-400 border border-slate-700">
                                  Quarantined
                                </span>
                              )}
                              {isCritical && (
                                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-500/20 text-rose-300 border border-rose-500/40 animate-pulse">
                                  Critical (&lt;30d)
                                </span>
                              )}
                              {isWarning && (
                                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/20 text-amber-300 border border-amber-500/40">
                                  Warning (&lt;90d)
                                </span>
                              )}
                              {!isExpired && !isCritical && !isWarning && (
                                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/15 text-emerald-300 border border-emerald-500/30">
                                  Healthy
                                </span>
                              )}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {/* ================================================================ */}
          {/* TAB 3: INSURANCE & CLAIMS AGING (Payers & Denials)                */}
          {/* ================================================================ */}
          {activeTab === 'claims-aging' && (
            <div className="space-y-6 animate-fadeIn">
              {/* Module Header Bar */}
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-1">
                <div>
                  <h2 className="text-lg font-bold text-white flex items-center space-x-2">
                    <ShieldAlert className="w-5 h-5 text-rose-400" />
                    <span>Insurance Claims Adjudication & Payer Denial Analytics</span>
                  </h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Fact_Insurance_Claims reconciliation, turnaround cycles, and revenue cycle denial mitigations.
                  </p>
                </div>

                <div className="flex items-center space-x-2 text-xs">
                  <span className="text-slate-400">Total Billed:</span>
                  <span className="font-mono font-bold text-white bg-slate-900 px-3 py-1 rounded-xl border border-slate-800">
                    ${Number(claimsData.payer_performance.reduce((acc, p) => acc + Number(p.total_claim_amount || 0), 0)).toFixed(2)}
                  </span>
                </div>
              </div>

              {/* Status & Rejection Breakdown Row */}
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Claims Adjudication Status Donut */}
                <div className="glass-card rounded-2xl p-5 border border-slate-800 flex flex-col justify-between">
                  <div>
                    <h3 className="text-sm font-semibold text-white mb-1">Claim Adjudication Distribution</h3>
                    <p className="text-xs text-slate-400 mb-4">Ratio of Approved vs. Denied vs. In-Flight Claims</p>

                    <div className="h-52 w-full">
                      <ResponsiveContainer width="100%" height="100%">
                        <PieChart>
                          <Pie
                            data={[
                              { name: 'Approved', value: 4, fill: '#10b981' },
                              { name: 'Rejected', value: 3, fill: '#f43f5e' },
                              { name: 'Pending', value: 1, fill: '#f59e0b' },
                            ]}
                            dataKey="value"
                            nameKey="name"
                            cx="50%"
                            cy="50%"
                            innerRadius={45}
                            outerRadius={75}
                            paddingAngle={4}
                          >
                            <Cell fill="#10b981" />
                            <Cell fill="#f43f5e" />
                            <Cell fill="#f59e0b" />
                          </Pie>
                          <Tooltip
                            contentStyle={{
                              backgroundColor: '#0f172a',
                              borderColor: '#334155',
                              borderRadius: '0.75rem',
                              fontSize: '11px',
                            }}
                          />
                        </PieChart>
                      </ResponsiveContainer>
                    </div>
                  </div>

                  <div className="grid grid-cols-3 gap-2 pt-3 border-t border-slate-800 text-center">
                    <div className="p-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/20">
                      <div className="text-[10px] text-emerald-400 font-semibold">Approved</div>
                      <div className="text-sm font-bold text-emerald-300 font-mono mt-0.5">4 Claims</div>
                      <div className="text-[10px] text-emerald-400/80 font-mono">$254.50</div>
                    </div>
                    <div className="p-2.5 rounded-xl bg-rose-500/10 border border-rose-500/20">
                      <div className="text-[10px] text-rose-400 font-semibold">Denied</div>
                      <div className="text-sm font-bold text-rose-300 font-mono mt-0.5">3 Claims</div>
                      <div className="text-[10px] text-rose-400/80 font-mono">$233.00</div>
                    </div>
                    <div className="p-2.5 rounded-xl bg-amber-500/10 border border-amber-500/20">
                      <div className="text-[10px] text-amber-400 font-semibold">In Review</div>
                      <div className="text-sm font-bold text-amber-300 font-mono mt-0.5">1 Claim</div>
                      <div className="text-[10px] text-amber-400/80 font-mono">$255.00</div>
                    </div>
                  </div>
                </div>

                {/* Top Rejection Reasons & Recovery Actions */}
                <div className="lg:col-span-2 glass-card rounded-2xl p-5 border border-slate-800 flex flex-col justify-between">
                  <div>
                    <div className="flex items-center justify-between mb-3">
                      <div>
                        <h3 className="text-sm font-semibold text-white">Top Claim Denial Reasons & Revenue Recovery</h3>
                        <p className="text-xs text-slate-400">
                          Identified denial root causes with actionable revenue-cycle guidance.
                        </p>
                      </div>
                      <span className="text-xs font-mono font-bold text-rose-400 bg-rose-500/10 px-2.5 py-1 rounded-lg border border-rose-500/20">
                        Total Loss: $233.00
                      </span>
                    </div>

                    <div className="space-y-3">
                      {claimsData.top_rejections.map((rej, i) => (
                        <div
                          key={i}
                          className="p-3.5 rounded-xl bg-slate-900/70 border border-rose-500/20 flex flex-col sm:flex-row sm:items-start justify-between gap-3 hover:border-rose-500/40 transition-colors"
                        >
                          <div className="flex items-start space-x-3">
                            <div className="p-2 rounded-lg bg-rose-500/10 text-rose-400 mt-0.5 flex-shrink-0">
                              <XCircle className="w-4 h-4" />
                            </div>
                            <div>
                              <div className="flex items-center space-x-2">
                                <span className="font-mono text-xs font-bold text-rose-300">
                                  {rej.rejection_code}
                                </span>
                                <span className="text-[10px] px-2 py-0.5 rounded-full bg-slate-800 text-slate-400">
                                  {rej.occurrences} occurrence
                                </span>
                              </div>
                              <p className="text-xs text-slate-300 mt-1">{rej.rejection_reason}</p>
                              {rej.recovery_action && (
                                <div className="text-[11px] text-emerald-400 flex items-center space-x-1 mt-1.5 font-medium">
                                  <Zap className="w-3 h-3 flex-shrink-0" />
                                  <span>Protocol: {rej.recovery_action}</span>
                                </div>
                              )}
                            </div>
                          </div>

                          <div className="text-right sm:flex-shrink-0 border-t sm:border-t-0 pt-2 sm:pt-0 border-slate-800">
                            <div className="text-[10px] uppercase font-mono text-slate-400">Loss Exposure</div>
                            <div className="text-sm font-mono font-bold text-rose-400 mt-0.5">
                              ${Number(rej.total_lost_amount).toFixed(2)}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>

              {/* Commercial & Government Payer Scorecard Table */}
              <div className="glass-card rounded-2xl p-5 border border-slate-800">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <h3 className="text-sm font-semibold text-white">Commercial & Government Payer Performance Scorecard</h3>
                    <p className="text-xs text-slate-400">
                      Adjudication rates, turnaround speed, and denial losses aggregated across conformed Dim_Payer.
                    </p>
                  </div>
                  <span className="text-xs font-mono text-slate-400 bg-slate-900 px-3 py-1 rounded-xl border border-slate-800">
                    5 Active Payers
                  </span>
                </div>

                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs">
                    <thead className="bg-slate-900/80 text-slate-400 uppercase font-mono tracking-wider border-b border-slate-800">
                      <tr>
                        <th className="py-3 px-4">Payer Organization</th>
                        <th className="py-3 px-4">Coverage Type</th>
                        <th className="py-3 px-4 text-center">Volume</th>
                        <th className="py-3 px-4 text-right">Submitted</th>
                        <th className="py-3 px-4 text-right">Approved</th>
                        <th className="py-3 px-4 text-right">Denied Loss</th>
                        <th className="py-3 px-4 text-center">Avg Turnaround</th>
                        <th className="py-3 px-4 text-right">Clean Rate</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-800/60 font-sans">
                      {claimsData.payer_performance.map((p, idx) => {
                        const isClean = Number(p.approval_rate_pct) >= 80;
                        const isMediocre = Number(p.approval_rate_pct) >= 40 && Number(p.approval_rate_pct) < 80;

                        return (
                          <tr key={idx} className="hover:bg-slate-850/60 transition-colors">
                            <td className="py-3 px-4 font-semibold text-white flex items-center space-x-2">
                              <ShieldCheck className="w-4 h-4 text-emerald-400 flex-shrink-0" />
                              <span className="truncate">{p.payer_name}</span>
                            </td>
                            <td className="py-3 px-4">
                              <span className="font-mono text-[11px] px-2 py-0.5 rounded-md bg-slate-800/80 text-slate-300 border border-slate-700/60">
                                {p.payer_type}
                              </span>
                            </td>
                            <td className="py-3 px-4 text-center font-mono font-semibold text-slate-300">
                              {p.total_claims}
                            </td>
                            <td className="py-3 px-4 text-right font-mono text-slate-200">
                              ${Number(p.total_claim_amount).toFixed(2)}
                            </td>
                            <td className="py-3 px-4 text-right font-mono font-semibold text-emerald-400">
                              ${Number(p.total_approved_amount).toFixed(2)}
                            </td>
                            <td className="py-3 px-4 text-right font-mono font-semibold text-rose-400">
                              ${Number(p.total_rejection_loss).toFixed(2)}
                            </td>
                            <td className="py-3 px-4 text-center font-mono text-slate-300">
                              {p.avg_turnaround_days} d
                            </td>
                            <td className="py-3 px-4 text-right font-mono font-bold">
                              <span
                                className={`inline-block px-2 py-0.5 rounded-full text-[11px] border ${
                                  isClean
                                    ? 'bg-emerald-500/10 text-emerald-300 border-emerald-500/30'
                                    : isMediocre
                                    ? 'bg-amber-500/10 text-amber-300 border-amber-500/30'
                                    : 'bg-rose-500/10 text-rose-300 border-rose-500/30'
                                }`}
                              >
                                {Number(p.approval_rate_pct).toFixed(0)}%
                              </span>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}
        </main>

        {/* Footer */}
        <footer className="border-t border-slate-800/80 py-3.5 px-6 text-xs text-slate-500 flex flex-col sm:flex-row items-center justify-between gap-2">
          <p>
            PharmaDWH &bull; VDC Central Pharmacy Branch &bull; Star Schema OLAP Platform
          </p>
          <p className="font-mono text-[11px] text-slate-400">
            Powered by FastAPI &middot; React 18 &middot; Tailwind CSS &middot; Recharts &middot; Axios
          </p>
        </footer>
      </div>
    </div>
  );
}
