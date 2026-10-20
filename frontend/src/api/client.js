import axios from 'axios';

/**
 * Axios API client instance pre-configured for the Pharmacy Data Warehouse
 * Analytical Query API service.
 */
const apiClient = axios.create({
  baseURL: 'http://localhost:8000/api/analytics',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
});

// Response interceptor for centralized error logging and handling
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    const errorDetails = {
      message: error.message,
      status: error.response?.status,
      data: error.response?.data,
      url: error.config?.url,
    };
    console.warn('[Analytics API Client] Request error:', errorDetails);
    return Promise.reject(error);
  }
);

/**
 * Helper API methods mapped to central_pharmacy_dwh star schema OLAP endpoints
 */
export const analyticsApi = {
  // High-level KPI aggregations
  getKPIs: () => apiClient.get('/kpis'),
  getKpiSummary: () => apiClient.get('/kpi-summary'),

  // Financial profitability & channel breakdown (Rx Dispensed vs OTC Retail)
  getProfitability: (period = 'monthly') =>
    apiClient.get('/profitability', { params: { period } }),

  // Inventory shelf life & reorder risk (< 180 days or low stock)
  getInventoryAlerts: (daysThreshold = 180, stockThreshold = 50) =>
    apiClient.get('/inventory-alerts', {
      params: { days_threshold: daysThreshold, stock_threshold: stockThreshold },
    }),

  // Payer claims adjudication, denial aging & rejection causes
  getClaimsSummary: () => apiClient.get('/claims-summary'),

  // Monthly sales & gross profit trend
  getSalesTrend: () => apiClient.get('/sales-trend'),

  // Therapeutic category revenue & margins
  getCategoryPerformance: () => apiClient.get('/category-performance'),

  // Top dispensed / prescribed medicines
  getTopPrescribedMedicines: () => apiClient.get('/top-prescribed-medicines'),

  // Trigger ELT pipeline procedure (sp_Run_Pharmacy_ELT)
  triggerEtl: () => apiClient.post('/trigger-etl'),
};

export default apiClient;
