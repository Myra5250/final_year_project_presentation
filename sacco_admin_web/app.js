const API_BASE = "http://127.0.0.1:8000/api";

const app = {
    token: localStorage.getItem('sacco_token'),
    user: JSON.parse(localStorage.getItem('sacco_user')),

    init() {
        this.setupEventListeners();
        if (this.token && this.user && this.user.is_admin) {
            this.showMain();
        } else {
            this.showLogin();
        }
    },

    setupEventListeners() {
        // View toggling
        document.getElementById('show-register')?.addEventListener('click', (e) => {
            e.preventDefault();
            document.getElementById('login-view').classList.add('hidden');
            document.getElementById('register-view').classList.remove('hidden');
        });

        document.getElementById('show-login')?.addEventListener('click', (e) => {
            e.preventDefault();
            document.getElementById('register-view').classList.add('hidden');
            document.getElementById('login-view').classList.remove('hidden');
        });

        // Login handling
        document.getElementById('login-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            await this.login(email, password);
        });

        // Register handling
        document.getElementById('register-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            const data = {
                full_name: document.getElementById('reg-fullname').value,
                username: document.getElementById('reg-username').value,
                email: document.getElementById('reg-email').value,
                phone_number: document.getElementById('reg-phone').value,
                password: document.getElementById('reg-password').value
            };
            await this.register(data);
        });

        // Navigation
        document.querySelectorAll('.nav-link[data-page]').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const page = link.getAttribute('data-page');
                this.navigate(page);
            });
        });

        // Logout
        document.getElementById('logout-btn').addEventListener('click', (e) => {
            e.preventDefault();
            this.logout();
        });
    },

    formatCurrency(amount) {
        return new Intl.NumberFormat('en-UG', {
            style: 'currency',
            currency: 'UGX',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(amount);
    },

    async login(email, password) {
        const errorEl = document.getElementById('login-error');
        errorEl.classList.add('hidden');

        try {
            const response = await fetch(`${API_BASE}/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email, password })
            });

            const data = await response.json();

            if (response.ok) {
                if (!data.user.is_admin) {
                    throw new Error("Access Denied: Administrative credentials required.");
                }
                this.token = data.token;
                this.user = data.user;
                localStorage.setItem('sacco_token', data.token);
                localStorage.setItem('sacco_user', JSON.stringify(data.user));
                this.showMain();
            } else {
                throw new Error(data.message || "Authentication failed. Please verify your credentials.");
            }
        } catch (err) {
            errorEl.textContent = err.message;
            errorEl.classList.remove('hidden');
        }
    },

    async register(data) {
        const errorEl = document.getElementById('register-error');
        errorEl.classList.add('hidden');

        try {
            const response = await fetch(`${API_BASE}/admin/register`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });

            const result = await response.json();

            if (response.ok) {
                alert("Corporate account created successfully. You may now sign in.");
                document.getElementById('show-login').click();
            } else {
                throw new Error(result.error || "Registration failed. Database conflict detected.");
            }
        } catch (err) {
            errorEl.textContent = err.message;
            errorEl.classList.remove('hidden');
        }
    },

    logout() {
        localStorage.clear();
        window.location.reload();
    },

    showLogin() {
        document.getElementById('login-overlay').classList.remove('hidden');
        document.getElementById('sidebar').classList.add('hidden');
        document.getElementById('main-content').classList.add('hidden');
    },

    showMain() {
        document.getElementById('login-overlay').classList.add('hidden');
        document.getElementById('sidebar').classList.remove('hidden');
        document.getElementById('main-content').classList.remove('hidden');
        document.getElementById('admin-name').textContent = this.user.username;
        document.getElementById('admin-avatar').textContent = this.user.username.charAt(0).toUpperCase();
        this.navigate('dashboard');
    },

    navigate(pageId) {
        // Update Nav UI
        document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
        document.querySelector(`.nav-link[data-page="${pageId}"]`)?.classList.add('active');

        // Show Page
        document.querySelectorAll('main section').forEach(s => s.classList.add('hidden'));
        document.getElementById(`page-${pageId}`).classList.remove('hidden');

        // Update Header
        const titles = {
            'dashboard': 'Executive Overview',
            'users': 'Member Management Console',
            'loans': 'Loan Application Pipeline',
            'transactions': 'Global Financial Audit',
            'settings': 'System Configuration'
        };
        document.getElementById('page-heading').textContent = titles[pageId];

        // Fetch Data
        this.fetchPageData(pageId);
    },

    async fetchPageData(pageId) {
        switch (pageId) {
            case 'dashboard':
                await this.refreshStats();
                await this.loadRecentLoans();
                break;
            case 'users':
                await this.loadUsers();
                break;
            case 'loans':
                await this.loadLoans();
                break;
            case 'transactions':
                await this.loadTransactions();
                break;
            case 'settings':
                await this.loadConfig();
                break;
        }
    },

    async apiFetch(endpoint) {
        const response = await fetch(`${API_BASE}${endpoint}`, {
            headers: { 'Authorization': `Bearer ${this.token}` }
        });
        if (response.status === 401 || response.status === 403) {
            this.logout();
            return null;
        }
        return response.json();
    },

    async refreshStats() {
        const stats = await this.apiFetch('/admin/stats');
        if (!stats) return;

        document.getElementById('stat-users').textContent = stats.total_users;
        document.getElementById('stat-savings').textContent = this.formatCurrency(stats.total_savings);
        document.getElementById('stat-shares').textContent = this.formatCurrency(stats.total_shares);
        document.getElementById('stat-loans').textContent = stats.pending_loans;
        document.getElementById('stat-disbursed').textContent = this.formatCurrency(stats.total_disbursed);
    },

    async loadRecentLoans() {
        const loans = await this.apiFetch('/admin/loans');
        if (!loans) return;

        const tbody = document.querySelector('#recent-loans-table tbody');
        tbody.innerHTML = loans.slice(0, 5).map(loan => `
            <tr>
                <td>
                    <div style="font-weight: 700;">${loan.full_name}</div>
                    <div style="font-size: 0.75rem; color: #64748b;">UID: ${loan.username}</div>
                </td>
                <td style="font-weight: 600;">${this.formatCurrency(loan.amount)}</td>
                <td>${loan.duration_months} Months</td>
                <td><span class="badge badge-${loan.status.toLowerCase()}">${loan.status}</span></td>
                <td>
                    ${loan.status === 'PENDING' ? `
                        <div style="display: flex; gap: 0.5rem;">
                            <button class="btn btn-primary btn-sm" onclick="app.loanAction(${loan.id}, 'APPROVED')">
                                <i class="fa-solid fa-check"></i> Approve
                            </button>
                            <button class="btn btn-danger btn-sm" onclick="app.loanAction(${loan.id}, 'REJECTED')">
                                <i class="fa-solid fa-xmark"></i> Reject
                            </button>
                        </div>
                    ` : '<span style="color: #94a3b8; font-style: italic;">Processed</span>'}
                </td>
            </tr>
        `).join('');
    },

    async loadUsers() {
        const users = await this.apiFetch('/admin/users');
        if (!users) return;

        const tbody = document.querySelector('#members-table tbody');
        tbody.innerHTML = users.map(u => `
            <tr>
                <td style="font-family: monospace; font-weight: 600; color: #6366f1;">#ACC-${u.id.toString().padStart(4, '0')}</td>
                <td><strong>${u.full_name}</strong></td>
                <td>
                    <div>${u.email}</div>
                    <div style="font-size: 0.75rem; color: #64748b;">${u.phone_number}</div>
                </td>
                <td style="font-weight: 600;">${this.formatCurrency(u.balance)}</td>
                <td style="color: var(--success); font-weight: 600;">${this.formatCurrency(u.savings_balance)}</td>
                <td style="color: var(--primary); font-weight: 600;">${this.formatCurrency(u.shares_balance)}</td>
                <td>${new Date(u.created_at).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })}</td>
            </tr>
        `).join('');
    },

    async loadLoans() {
        const loans = await this.apiFetch('/admin/loans');
        if (!loans) return;

        const tbody = document.querySelector('#loans-table tbody');
        tbody.innerHTML = loans.map(loan => `
            <tr>
                <td style="font-family: monospace;">#LN-${loan.id}</td>
                <td><strong>${loan.full_name}</strong></td>
                <td style="font-weight: 700;">${this.formatCurrency(loan.amount)}</td>
                <td style="max-width: 200px; font-size: 0.8125rem;">${loan.reason}</td>
                <td>${new Date(loan.applied_at).toLocaleDateString()}</td>
                <td><span class="badge badge-${loan.status.toLowerCase()}">${loan.status}</span></td>
                <td>
                    ${loan.status === 'PENDING' ? `
                        <div style="display: flex; gap: 0.5rem;">
                            <button class="btn btn-primary btn-sm" onclick="app.loanAction(${loan.id}, 'APPROVED')">Approve</button>
                            <button class="btn btn-danger btn-sm" onclick="app.loanAction(${loan.id}, 'REJECTED')">Reject</button>
                        </div>
                    ` : '-'}
                </td>
            </tr>
        `).join('');
    },

    async loadTransactions() {
        const txs = await this.apiFetch('/admin/transactions');
        if (!txs) return;

        const tbody = document.querySelector('#transactions-table tbody');
        tbody.innerHTML = txs.map(t => `
            <tr>
                <td><code style="background: #f1f5f9; padding: 0.2rem 0.5rem; border-radius: 4px;">${t.reference_code}</code></td>
                <td>${t.username}</td>
                <td style="font-weight: 700; color: ${t.amount < 0 ? 'var(--danger)' : 'var(--success)'}">${this.formatCurrency(t.amount)}</td>
                <td><span class="badge badge-${this.getTxTypeBadge(t.transaction_type)}">${t.transaction_type}</span></td>
                <td><span class="badge badge-success">COMPLETED</span></td>
                <td style="font-size: 0.8125rem; color: #64748b;">${new Date(t.created_at).toLocaleString()}</td>
            </tr>
        `).join('');
    },

    getTxTypeBadge(type) {
        if (type === 'LOAN_DISBURSEMENT') return 'info';
        if (type === 'DEPOSIT') return 'success';
        if (type === 'WITHDRAWAL') return 'danger';
        return 'secondary';
    },

    async loanAction(id, action) {
        if (!confirm(`Are you sure you want to officially ${action.toLowerCase()} this loan application?`)) return;

        try {
            const response = await fetch(`${API_BASE}/admin/loans/action`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.token}`
                },
                body: JSON.stringify({ loan_id: id, action })
            });

            if (response.ok) {
                alert(`Loan ${action.toLowerCase()} procedure completed.`);
                this.navigate(document.querySelector('.nav-link.active').getAttribute('data-page'));
            } else {
                const data = await response.json();
                alert(data.error || "Administrative action failed.");
            }
        } catch (err) {
            alert("System Error: " + err.message);
        }
    },

    async updateConfig(e) {
        e.preventDefault();
        const interest_rate = document.getElementById('conf-interest').value;
        const share_price = document.getElementById('conf-share-price').value;

        try {
            const response = await fetch(`${API_BASE}/admin/config`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.token}`
                },
                body: JSON.stringify({ interest_rate, share_price })
            });

            if (response.ok) {
                alert("System configuration updated successfully!");
            } else {
                throw new Error("Failed to update configuration");
            }
        } catch (err) {
            alert(err.message);
        }
    },

    async loadConfig() {
        const config = await this.apiFetch('/admin/config');
        if (config) {
            document.getElementById('conf-interest').value = config.loan_interest_rate;
            document.getElementById('conf-share-price').value = config.share_price;
        }
    }
};

document.addEventListener('DOMContentLoaded', () => app.init());
