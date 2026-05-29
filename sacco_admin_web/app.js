const API_BASE = "http://127.0.0.1:8000/api";

// ============================================================
// TOAST NOTIFICATION SYSTEM
// ============================================================
const toast = {
    container: null,
    init() { this.container = document.getElementById('toast-container'); },
    show(message, type = 'info', duration = 4000) {
        if (!this.container) this.init();
        const id = Date.now() + Math.random();
        const icons = { success: 'fa-circle-check', error: 'fa-circle-xmark', warning: 'fa-triangle-exclamation', info: 'fa-circle-info' };
        const el = document.createElement('div');
        el.className = `toast toast-${type}`;
        el.id = `toast-${id}`;
        el.innerHTML = `<i class="fa-solid ${icons[type] || icons.info} toast-icon"></i><span class="toast-message">${message}</span><button class="toast-close" onclick="toast.dismiss('${id}')">&times;</button>`;
        this.container.appendChild(el);
        setTimeout(() => el.classList.add('toast-visible'), 10);
        setTimeout(() => this.dismiss(id), duration);
    },
    dismiss(id) {
        const el = document.getElementById(`toast-${id}`);
        if (el) { el.classList.remove('toast-visible'); el.classList.add('toast-hiding'); setTimeout(() => el.remove(), 350); }
    },
    success(msg) { this.show(msg, 'success'); },
    error(msg) { this.show(msg, 'error', 6000); },
    warning(msg) { this.show(msg, 'warning', 5000); },
    info(msg) { this.show(msg, 'info'); }
};

// ============================================================
// LOGIN SECURITY - Brute Force Protection
// ============================================================
const loginSecurity = {
    maxAttempts: 5,
    lockoutMs: 5 * 60 * 1000,
    getState() {
        try { return JSON.parse(localStorage.getItem('login_security') || '{"attempts":0,"lockedUntil":0}'); }
        catch { return { attempts: 0, lockedUntil: 0 }; }
    },
    setState(s) { localStorage.setItem('login_security', JSON.stringify(s)); },
    isLocked() {
        const s = this.getState();
        if (s.lockedUntil && Date.now() < s.lockedUntil) return s.lockedUntil;
        if (s.lockedUntil && Date.now() >= s.lockedUntil) this.setState({ attempts: 0, lockedUntil: 0 });
        return false;
    },
    recordFailure() {
        const s = this.getState();
        s.attempts++;
        if (s.attempts >= this.maxAttempts) s.lockedUntil = Date.now() + this.lockoutMs;
        this.setState(s);
        return s;
    },
    recordSuccess() { this.setState({ attempts: 0, lockedUntil: 0 }); },
    remaining() { return Math.max(0, this.maxAttempts - this.getState().attempts); }
};

// ============================================================
// MAIN APPLICATION OBJECT
// ============================================================
const app = {
    token: localStorage.getItem('sacco_token'),
    user: JSON.parse(localStorage.getItem('sacco_user') || 'null'),
    refreshInterval: null,

    // ─── INIT ──────────────────────────────────────────────────
    init() {
        toast.init();
        this.setupTheme();
        this.setupEventListeners();
        this.setupModalListeners();
        this.setupSearchListener();
        this.setupPasswordToggles();
        if (this.token && this.user && this.user.is_admin) {
            this.showMain();
        } else {
            this.showLogin();
        }
        this.checkLockout();
    },

    checkLockout() {
        const lockoutTime = loginSecurity.isLocked();
        if (lockoutTime) this.showLockoutCountdown(lockoutTime);
    },

    showLockoutCountdown(lockoutTime) {
        const btn = document.getElementById('login-submit-btn');
        const errEl = document.getElementById('login-error');
        const tick = () => {
            const rem = Math.ceil((lockoutTime - Date.now()) / 1000);
            if (rem <= 0) {
                if (btn) { btn.disabled = false; btn.innerHTML = '<i class="fa-solid fa-lock"></i> Secure Login'; }
                if (errEl) errEl.classList.add('hidden');
                return;
            }
            const m = Math.floor(rem / 60), s = rem % 60;
            if (errEl) { errEl.textContent = `🔒 Account locked. Retry in ${m}:${s.toString().padStart(2,'0')}`; errEl.classList.remove('hidden'); }
            if (btn) btn.disabled = true;
            setTimeout(tick, 1000);
        };
        tick();
    },

    // ─── PASSWORD TOGGLES & STRENGTH ─────────────────────────
    setupPasswordToggles() {
        const makeToggle = (btnId, inputId) => {
            const btn = document.getElementById(btnId);
            const inp = document.getElementById(inputId);
            if (btn && inp) btn.addEventListener('click', () => {
                const isPass = inp.type === 'password';
                inp.type = isPass ? 'text' : 'password';
                btn.className = `fa-solid ${isPass ? 'fa-eye' : 'fa-eye-slash'}`;
            });
        };
        makeToggle('toggle-password', 'password');
        makeToggle('toggle-reg-password', 'reg-password');

        const regPass = document.getElementById('reg-password');
        if (regPass) regPass.addEventListener('input', () => this.updateStrength(regPass.value));
    },

    updateStrength(password) {
        const container = document.getElementById('password-strength-container');
        const text = document.getElementById('strength-text');
        if (!container) return;
        container.style.display = password.length > 0 ? 'block' : 'none';
        let score = 0;
        if (password.length >= 8) score++;
        if (/[A-Z]/.test(password) && /[a-z]/.test(password)) score++;
        if (/[0-9]/.test(password)) score++;
        if (/[^A-Za-z0-9]/.test(password)) score++;
        const colors = ['#ef4444', '#f59e0b', '#10b981'];
        const labels = ['Weak', 'Fair', 'Strong'];
        const level = score <= 1 ? 0 : score <= 2 ? 1 : 2;
        for (let i = 1; i <= 3; i++) {
            const bar = document.getElementById(`strength-bar-${i}`);
            if (bar) bar.style.background = i <= (level + 1) ? colors[level] : '#cbd5e1';
        }
        if (text) { text.textContent = `Strength: ${labels[level]}`; text.style.color = colors[level]; }
    },

    // ─── EVENT LISTENERS ───────────────────────────────────────
    setupEventListeners() {
        document.getElementById('show-register')?.addEventListener('click', e => {
            e.preventDefault();
            document.getElementById('login-view').classList.add('hidden');
            document.getElementById('register-view').classList.remove('hidden');
        });
        document.getElementById('show-login')?.addEventListener('click', e => {
            e.preventDefault();
            document.getElementById('register-view').classList.add('hidden');
            document.getElementById('login-view').classList.remove('hidden');
        });
        document.getElementById('login-form')?.addEventListener('submit', async e => {
            e.preventDefault();
            const lockout = loginSecurity.isLocked();
            if (lockout) { this.showLockoutCountdown(lockout); return; }
            await this.login(document.getElementById('email').value, document.getElementById('password').value);
        });
        document.getElementById('register-form')?.addEventListener('submit', async e => {
            e.preventDefault();
            const phone = document.getElementById('reg-phone').value;
            if (!/^\d{10}$/.test(phone)) {
                alert('Phone number must be exactly 10 digits.');
                return;
            }
            await this.register({
                full_name: document.getElementById('reg-fullname').value,
                username: document.getElementById('reg-username').value,
                email: document.getElementById('reg-email').value,
                phone_number: phone,
                password: document.getElementById('reg-password').value
            });
        });
        document.querySelectorAll('.nav-link[data-page]').forEach(link =>
            link.addEventListener('click', e => { e.preventDefault(); this.navigate(link.getAttribute('data-page')); })
        );
        document.getElementById('logout-btn')?.addEventListener('click', e => { e.preventDefault(); this.logout(); });
        document.getElementById('theme-toggle-btn')?.addEventListener('click', () => this.toggleTheme());

        // Settings Tabs
        document.querySelectorAll('.settings-tab-btn').forEach(btn =>
            btn.addEventListener('click', () => this.switchSettingsTab(btn.getAttribute('data-tab')))
        );

        // Notification Bell
        document.getElementById('notif-bell')?.addEventListener('click', e => {
            e.stopPropagation();
            document.getElementById('notif-dropdown')?.classList.toggle('hidden');
        });
        document.getElementById('notif-dropdown')?.addEventListener('click', e => {
            e.stopPropagation();
        });
        document.getElementById('notif-mark-all-read')?.addEventListener('click', e => {
            e.preventDefault();
            e.stopPropagation();
            this.markAllNotificationsRead();
        });
        document.addEventListener('click', () => document.getElementById('notif-dropdown')?.classList.add('hidden'));
    },

    switchSettingsTab(tabId) {
        document.querySelectorAll('.settings-tab-btn').forEach(b => b.classList.toggle('active', b.getAttribute('data-tab') === tabId));
        document.querySelectorAll('.settings-tab-content').forEach(c => c.classList.add('hidden'));
        document.getElementById(`settings-tab-${tabId}`)?.classList.remove('hidden');
        if (tabId === 'admins') this.loadAdmins();
        if (tabId === 'profile') this.loadProfileData();
        if (tabId === 'system') this.loadSystemInfo();
    },

    // ─── THEME ─────────────────────────────────────────────────
    setupTheme() {
        if (localStorage.getItem('sacco_theme') === 'dark') {
            document.body.classList.add('dark-mode');
            document.querySelector('#theme-toggle-btn i')?.classList.replace('fa-moon', 'fa-sun');
        }
    },

    toggleTheme() {
        const dark = document.body.classList.toggle('dark-mode');
        localStorage.setItem('sacco_theme', dark ? 'dark' : 'light');
        const icon = document.querySelector('#theme-toggle-btn i');
        if (icon) dark ? icon.classList.replace('fa-moon', 'fa-sun') : icon.classList.replace('fa-sun', 'fa-moon');
    },

    // ─── FORMATTING ────────────────────────────────────────────
    formatCurrency(amount) {
        return new Intl.NumberFormat('en-UG', { style: 'currency', currency: 'UGX', minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(amount);
    },

    // ─── AUTH ──────────────────────────────────────────────────
    async login(email, password) {
        const errEl = document.getElementById('login-error');
        const btn = document.getElementById('login-submit-btn');
        errEl?.classList.add('hidden');
        if (btn) { btn.disabled = true; btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Authenticating...'; }
        try {
            const res = await fetch(`${API_BASE}/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email, password })
            });
            const data = await res.json();
            if (res.ok) {
                if (!data.user.is_admin) {
                    loginSecurity.recordFailure();
                    throw new Error("Access Denied: Administrative credentials required.");
                }
                loginSecurity.recordSuccess();
                this.token = data.token;
                this.user = data.user;
                localStorage.setItem('sacco_token', data.token);
                localStorage.setItem('sacco_user', JSON.stringify(data.user));
                this.showMain();
            } else {
                const state = loginSecurity.recordFailure();
                const rem = loginSecurity.maxAttempts - state.attempts;
                if (state.lockedUntil) {
                    this.showLockoutCountdown(state.lockedUntil);
                    throw new Error("Too many failed attempts. Account locked for 5 minutes.");
                } else if (rem <= 2) {
                    throw new Error(`${data.message || 'Invalid credentials.'} ${rem} attempt${rem !== 1 ? 's' : ''} remaining before lockout.`);
                } else {
                    throw new Error(data.message || "Authentication failed. Please verify your credentials.");
                }
            }
        } catch (err) {
            if (errEl) { errEl.textContent = err.message; errEl.classList.remove('hidden'); }
            if (btn) { btn.disabled = false; btn.innerHTML = '<i class="fa-solid fa-lock"></i> Secure Login'; }
        }
    },

    async register(data) {
        const errEl = document.getElementById('register-error');
        errEl?.classList.add('hidden');
        try {
            const res = await fetch(`${API_BASE}/admin/register`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            const result = await res.json();
            if (res.ok) {
                toast.success("Administrative account created! You may now sign in.");
                document.getElementById('show-login')?.click();
            } else {
                throw new Error(result.error || "Registration failed.");
            }
        } catch (err) {
            if (errEl) { errEl.textContent = err.message; errEl.classList.remove('hidden'); }
        }
    },

    logout() {
        if (this.refreshInterval) clearInterval(this.refreshInterval);
        localStorage.removeItem('sacco_token');
        localStorage.removeItem('sacco_user');
        this.token = null; this.user = null;
        window.location.reload();
    },

    showLogin() {
        document.getElementById('login-overlay')?.classList.remove('hidden');
        document.getElementById('sidebar')?.classList.add('hidden');
        document.getElementById('main-content')?.classList.add('hidden');
    },

    showMain() {
        document.getElementById('login-overlay')?.classList.add('hidden');
        document.getElementById('sidebar')?.classList.remove('hidden');
        document.getElementById('main-content')?.classList.remove('hidden');
        if (this.user) {
            const name = this.user.full_name || this.user.username;
            document.getElementById('admin-name').textContent = this.user.username;
            document.getElementById('admin-avatar').textContent = name.charAt(0).toUpperCase();
        }
        this.navigate('dashboard');
        // Auto-refresh stats every 60 seconds
        this.refreshInterval = setInterval(() => {
            if (document.querySelector('.nav-link.active')?.getAttribute('data-page') === 'dashboard') this.refreshStats();
        }, 60000);
    },

    // ─── NAVIGATION ────────────────────────────────────────────
    navigate(pageId) {
        document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
        document.querySelector(`.nav-link[data-page="${pageId}"]`)?.classList.add('active');
        document.querySelectorAll('main section').forEach(s => s.classList.add('hidden'));
        document.getElementById(`page-${pageId}`)?.classList.remove('hidden');
        const titles = { dashboard: 'Executive Overview', users: 'Member Management Console', loans: 'Loan Application Pipeline', transactions: 'Global Financial Audit', settings: 'System Configuration' };
        document.getElementById('page-heading').textContent = titles[pageId] || pageId;
        this.fetchPageData(pageId);
    },

    async fetchPageData(pageId) {
        switch (pageId) {
            case 'dashboard': await this.refreshStats(); await this.loadRecentLoans(); break;
            case 'users': await this.loadUsers(); break;
            case 'loans': await this.loadLoans(); break;
            case 'transactions': await this.loadTransactions(); break;
            case 'settings': await this.loadConfig(); break;
        }
    },

    // ─── API HELPERS ───────────────────────────────────────────
    async apiFetch(endpoint) {
        try {
            const res = await fetch(`${API_BASE}${endpoint}`, { headers: { 'Authorization': `Bearer ${this.token}` } });
            if (res.status === 401 || res.status === 403) { toast.error("Session expired. Logging out..."); setTimeout(() => this.logout(), 1500); return null; }
            return res.json();
        } catch { toast.error("Network error. Is the backend running on port 8000?"); return null; }
    },

    async apiPost(endpoint, body) {
        try {
            const res = await fetch(`${API_BASE}${endpoint}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.token}` },
                body: JSON.stringify(body)
            });
            if (res.status === 401 || res.status === 403) { toast.error("Session expired."); setTimeout(() => this.logout(), 1500); return null; }
            return res;
        } catch { toast.error("Network error. Is the backend running?"); return null; }
    },

    async apiPut(endpoint, body) {
        try {
            const res = await fetch(`${API_BASE}${endpoint}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.token}` },
                body: JSON.stringify(body)
            });
            if (res.status === 401 || res.status === 403) { toast.error("Session expired."); setTimeout(() => this.logout(), 1500); return null; }
            return res;
        } catch { toast.error("Network error."); return null; }
    },

    // ─── DASHBOARD ─────────────────────────────────────────────
    async refreshStats() {
        const stats = await this.apiFetch('/admin/stats');
        if (!stats) return;

        const s = id => document.getElementById(id);
        if (s('stat-users')) s('stat-users').textContent = stats.total_users;
        if (s('stat-savings')) s('stat-savings').textContent = this.formatCurrency(stats.total_savings);
        if (s('stat-shares')) s('stat-shares').textContent = this.formatCurrency(stats.total_shares);
        if (s('stat-loans')) s('stat-loans').textContent = stats.pending_loans;
        if (s('stat-disbursed')) s('stat-disbursed').textContent = this.formatCurrency(stats.total_disbursed);

        // Notification bell update
        await this.loadNotifications(stats.pending_loans);

        // Welcome banner
        const hour = new Date().getHours();
        const greeting = hour < 12 ? 'GOOD MORNING,' : hour < 18 ? 'GOOD AFTERNOON,' : 'GOOD EVENING,';
        if (s('welcome-greeting-text')) s('welcome-greeting-text').textContent = greeting;
        if (s('welcome-admin-name') && this.user) s('welcome-admin-name').textContent = this.user.full_name || this.user.username;
        if (s('welcome-admin-avatar') && this.user) s('welcome-admin-avatar').textContent = (this.user.full_name || this.user.username).charAt(0).toUpperCase();
        if (s('welcome-system-date')) s('welcome-system-date').textContent = new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });

        // System info stats (if visible)
        ['sys-stat-users', 'sys-stat-savings', 'sys-stat-shares', 'sys-stat-loans', 'sys-stat-disbursed'].forEach((id, i) => {
            const vals = [stats.total_users, this.formatCurrency(stats.total_savings), this.formatCurrency(stats.total_shares), stats.pending_loans, this.formatCurrency(stats.total_disbursed)];
            if (s(id)) s(id).textContent = vals[i];
        });

        this.renderCharts(stats);
    },

    async loadNotifications(pendingLoanCount = 0) {
        const notifs = await this.apiFetch('/admin/notifications');
        const s = id => document.getElementById(id);
        const listEl = document.getElementById('notif-items-list');
        if (!listEl) return;

        let html = '';
        
        // Keep the standard pending loans item at the top if there are pending loans
        if (pendingLoanCount > 0) {
            html += `
                <div class="notif-item" onclick="app.navigate('loans')" style="border-bottom: 1px solid var(--sidebar-border);">
                    <i class="fa-solid fa-hourglass-half" style="color: var(--warning); margin-right: 0.75rem;"></i>
                    <div style="flex: 1;">
                        <div class="notif-item-title" style="font-weight: 700;">Pending Loan Applications</div>
                        <div class="notif-item-sub" style="font-size: 0.75rem; color: var(--text-muted);">${pendingLoanCount} awaiting your review</div>
                    </div>
                </div>`;
        }

        // Calculate unread db notifications
        let unreadDbCount = 0;

        if (notifs && notifs.length > 0) {
            unreadDbCount = notifs.filter(n => n.is_unread || n.is_unread === 1).length;
            
            notifs.forEach(n => {
                const isUnread = n.is_unread || n.is_unread === 1;
                const timeStr = new Date(n.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) + ' • ' + new Date(n.created_at).toLocaleDateString();
                
                // Color & Icon logic
                let color = 'var(--primary)';
                let icon = 'fa-bell';
                if (n.title.toLowerCase().includes('loan')) {
                    color = 'var(--warning)';
                    icon = 'fa-hand-holding-dollar';
                } else if (n.title.toLowerCase().includes('deposit')) {
                    color = 'var(--success)';
                    icon = 'fa-piggy-bank';
                } else if (n.title.toLowerCase().includes('withdraw')) {
                    color = 'var(--danger)';
                    icon = 'fa-money-bill-transfer';
                }
                
                html += `
                    <div class="notif-item ${isUnread ? 'unread' : ''}" onclick="app.markNotificationRead(${n.id})" style="border-bottom: 1px solid var(--sidebar-border); display: flex; align-items: start; padding: 0.75rem 1rem; cursor: pointer; ${isUnread ? 'background: rgba(var(--primary-rgb, 16, 185, 129), 0.08); font-weight: 500;' : ''}">
                        <i class="fa-solid ${icon}" style="color: ${color}; margin-right: 0.75rem; margin-top: 0.2rem; font-size: 1rem; flex-shrink: 0;"></i>
                        <div style="flex: 1; text-align: left;">
                            <div class="notif-item-title" style="font-weight: ${isUnread ? '700' : '500'}; font-size: 0.85rem; color: var(--text-dark);">${n.title}</div>
                            <div class="notif-item-sub" style="font-size: 0.75rem; color: var(--text-muted); margin-top: 0.1rem; line-height: 1.3;">${n.message}</div>
                            <div style="font-size: 0.65rem; color: var(--text-muted); margin-top: 0.25rem;">${timeStr}</div>
                        </div>
                        ${isUnread ? '<span style="width: 8px; height: 8px; border-radius: 50%; background: var(--primary); align-self: center; margin-left: 0.5rem; flex-shrink: 0;"></span>' : ''}
                    </div>`;
            });
        } else if (pendingLoanCount === 0) {
            html = '<div style="padding: 2rem 1rem; text-align: center; color: var(--text-muted); font-size: 0.85rem;"><i class="fa-regular fa-bell" style="font-size: 1.5rem; margin-bottom: 0.5rem; display: block;"></i>No notifications yet</div>';
        }

        listEl.innerHTML = html;

        // Update badges
        const totalUnread = pendingLoanCount + unreadDbCount;
        if (totalUnread > 0) {
            s('notif-badge')?.classList.remove('hidden');
            if (s('notif-loan-count')) {
                s('notif-loan-count').textContent = totalUnread;
                s('notif-loan-count').style.display = 'inline-block';
            }
            if (s('notif-loan-count-sub')) s('notif-loan-count-sub').textContent = pendingLoanCount;
        } else {
            s('notif-badge')?.classList.add('hidden');
            if (s('notif-loan-count')) s('notif-loan-count').style.display = 'none';
        }
    },

    async markNotificationRead(id) {
        try {
            await this.apiPut(`/admin/notifications/${id}/read`);
            await this.refreshStats();
        } catch (e) {
            console.error("Failed to mark read", e);
        }
    },

    async markAllNotificationsRead() {
        try {
            await this.apiPut('/admin/notifications/read-all');
            toast.success("All notifications marked as read!");
            await this.refreshStats();
        } catch (e) {
            console.error("Failed to mark all read", e);
        }
    },

    async loadRecentLoans() {
        const loans = await this.apiFetch('/admin/loans');
        if (!loans) return;
        const tbody = document.querySelector('#recent-loans-table tbody');
        if (!tbody) return;
        tbody.innerHTML = loans.slice(0, 5).map(loan => `
            <tr>
                <td>
                    <div style="font-weight:700;">${loan.full_name}</div>
                    <div style="font-size:0.72rem;color:var(--text-muted);">@${loan.username}</div>
                </td>
                <td style="font-weight:700;color:var(--primary);">${this.formatCurrency(loan.amount)}</td>
                <td>${loan.duration_months} Months</td>
                <td><span class="badge badge-${loan.status.toLowerCase()}">${loan.status}</span></td>
                <td>
                    ${loan.status === 'PENDING' ? `
                        <div style="display:flex;gap:0.4rem;">
                            <button class="btn btn-primary btn-sm" onclick="app.loanAction(${loan.id},'APPROVED')"><i class="fa-solid fa-check"></i> Approve</button>
                            <button class="btn btn-danger btn-sm" onclick="app.loanAction(${loan.id},'REJECTED')"><i class="fa-solid fa-xmark"></i> Reject</button>
                        </div>` : '<span style="color:var(--text-muted);font-style:italic;">Processed</span>'}
                </td>
            </tr>`).join('') || '<tr><td colspan="5" style="text-align:center;color:var(--text-muted);padding:2rem;">No loan applications found.</td></tr>';
    },

    async loadUsers() {
        const config = await this.apiFetch('/admin/config');
        const sharePrice = config ? (parseFloat(config.share_price) || 100.0) : 100.0;
        
        const users = await this.apiFetch('/admin/users');
        if (!users) return;
        const tbody = document.querySelector('#members-table tbody');
        if (!tbody) return;
        tbody.innerHTML = users.map(u => {
            const sharesCount = (parseFloat(u.shares_balance) / sharePrice).toFixed(0);
            return `
            <tr>
                <td><span style="font-family:monospace;font-weight:600;color:var(--primary);background:var(--primary-light);padding:0.2rem 0.6rem;border-radius:6px;">#ACC-${u.id.toString().padStart(4,'0')}</span></td>
                <td>
                    <div style="display:flex;align-items:center;gap:0.75rem;">
                        <div style="width:34px;height:34px;border-radius:50%;background:linear-gradient(135deg,var(--primary),#10b981);display:flex;align-items:center;justify-content:center;color:white;font-weight:700;font-size:0.85rem;flex-shrink:0;">${u.full_name.charAt(0).toUpperCase()}</div>
                        <div><div style="font-weight:700;">${u.full_name}</div><div style="font-size:0.72rem;color:var(--text-muted);">@${u.username}</div></div>
                    </div>
                </td>
                <td><div>${u.email}</div><div style="font-size:0.72rem;color:var(--text-muted);">${u.phone_number}</div></td>
                <td style="font-weight:600;">${this.formatCurrency(u.balance)}</td>
                <td style="color:var(--success);font-weight:600;">${this.formatCurrency(u.savings_balance)}</td>
                <td style="color:var(--primary);font-weight:600;">${this.formatCurrency(u.shares_balance)} <span style="font-size:0.75rem;color:var(--text-muted);font-weight:normal;">(${sharesCount} Shares)</span></td>
                <td style="color:var(--text-muted);font-size:0.85rem;">${new Date(u.created_at).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })}</td>
            </tr>`;
        }).join('') || '<tr><td colspan="7" style="text-align:center;color:var(--text-muted);padding:2rem;">No members found.</td></tr>';
    },

    async loadLoans() {
        const loans = await this.apiFetch('/admin/loans');
        if (!loans) return;
        const tbody = document.querySelector('#loans-table tbody');
        if (!tbody) return;
        tbody.innerHTML = loans.map(loan => `
            <tr>
                <td><span style="font-family:monospace;font-weight:600;">#LN-${loan.id.toString().padStart(4,'0')}</span></td>
                <td><div style="font-weight:700;">${loan.full_name}</div><div style="font-size:0.72rem;color:var(--text-muted);">@${loan.username}</div></td>
                <td style="font-weight:700;color:var(--primary);">${this.formatCurrency(loan.amount)}</td>
                <td style="max-width:200px;font-size:0.8rem;color:var(--text-muted);">${loan.reason}</td>
                <td style="font-size:0.85rem;">${new Date(loan.applied_at).toLocaleDateString()}</td>
                <td><span class="badge badge-${loan.status.toLowerCase()}">${loan.status}</span></td>
                <td>
                    ${loan.status === 'PENDING' ? `
                        <div style="display:flex;gap:0.4rem;">
                            <button class="btn btn-primary btn-sm" onclick="app.loanAction(${loan.id},'APPROVED')"><i class="fa-solid fa-check"></i> Approve</button>
                            <button class="btn btn-danger btn-sm" onclick="app.loanAction(${loan.id},'REJECTED')"><i class="fa-solid fa-xmark"></i> Reject</button>
                        </div>` : '—'}
                </td>
            </tr>`).join('') || '<tr><td colspan="7" style="text-align:center;color:var(--text-muted);padding:2rem;">No loans found.</td></tr>';
    },

    async loadTransactions() {
        const txs = await this.apiFetch('/admin/transactions');
        if (!txs) return;
        const tbody = document.querySelector('#transactions-table tbody');
        if (!tbody) return;
        tbody.innerHTML = txs.map(t => `
            <tr>
                <td><code style="background:var(--primary-light);color:var(--primary);padding:0.2rem 0.5rem;border-radius:4px;font-size:0.8rem;">${t.reference_code}</code></td>
                <td style="font-weight:600;">${t.username}</td>
                <td style="font-weight:700;color:${['WITHDRAWAL','LOAN_REPAYMENT'].includes(t.transaction_type)?'var(--danger)':'var(--success)'};">
                    ${['WITHDRAWAL','LOAN_REPAYMENT'].includes(t.transaction_type)?'-':'+'} ${this.formatCurrency(Math.abs(t.amount))}
                </td>
                <td><span class="badge badge-${this.getTxBadge(t.transaction_type)}">${t.transaction_type.replace(/_/g,' ')}</span></td>
                <td><span class="badge badge-success">COMPLETED</span></td>
                <td style="font-size:0.8rem;color:var(--text-muted);">${new Date(t.created_at).toLocaleString()}</td>
            </tr>`).join('') || '<tr><td colspan="6" style="text-align:center;color:var(--text-muted);padding:2rem;">No transactions found.</td></tr>';
    },

    getTxBadge(type) {
        const map = { LOAN_DISBURSEMENT: 'info', DEPOSIT: 'success', WITHDRAWAL: 'danger', LOAN_REPAYMENT: 'warning', SHARE_PURCHASE: 'info', TRANSFER: 'secondary' };
        return map[type] || 'secondary';
    },

    async loanAction(id, action) {
        if (!confirm(`Are you sure you want to ${action.toLowerCase()} this loan?`)) return;
        try {
            const res = await fetch(`${API_BASE}/admin/loans/action`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.token}` },
                body: JSON.stringify({ loan_id: id, action })
            });
            if (res.ok) {
                toast.success(`Loan ${action === 'APPROVED' ? 'approved ✓' : 'rejected'} successfully.`);
                const page = document.querySelector('.nav-link.active')?.getAttribute('data-page') || 'dashboard';
                this.navigate(page);
            } else {
                const data = await res.json();
                toast.error(data.error || "Action failed.");
            }
        } catch (err) { toast.error("Error: " + err.message); }
    },

    // ─── SETTINGS: FINANCIAL CONFIG ────────────────────────────
    async loadConfig() {
        const config = await this.apiFetch('/admin/config');
        if (!config) return;
        const set = (id, val) => { const el = document.getElementById(id); if (el && val != null) el.value = val; };
        set('conf-interest', config.loan_interest_rate);
        set('conf-share-price', config.share_price);
        set('conf-min-balance', config.min_balance);
        set('conf-loan-multiplier', config.loan_multiplier);
        set('conf-reg-fee', config.reg_fee);
        set('conf-max-withdraw', config.max_withdraw);
        const toggle = (id, val) => { const el = document.getElementById(id); if (el) el.checked = Boolean(val); };
        toggle('conf-maintenance', config.maintenance_mode);
        toggle('conf-allow-register', config.allow_register !== 0);
        toggle('conf-allow-loans', config.allow_loans !== 0);
    },

    async updateConfig(e) {
        e.preventDefault();
        const g = id => document.getElementById(id)?.value;
        try {
            const res = await fetch(`${API_BASE}/admin/config`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.token}` },
                body: JSON.stringify({
                    interest_rate: g('conf-interest'), share_price: g('conf-share-price'),
                    min_balance: g('conf-min-balance'), loan_multiplier: g('conf-loan-multiplier'),
                    reg_fee: g('conf-reg-fee'), max_withdraw: g('conf-max-withdraw')
                })
            });
            if (res.ok) toast.success("Financial configuration saved successfully!");
            else { const d = await res.json(); toast.error(d.error || "Failed to save."); }
        } catch (err) { toast.error(err.message); }
    },

    // ─── SETTINGS: SECURITY ────────────────────────────────────
    async saveSecuritySettings() {
        const g = id => document.getElementById(id)?.checked ? 1 : 0;
        try {
            const res = await fetch(`${API_BASE}/admin/config`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.token}` },
                body: JSON.stringify({ maintenance_mode: g('conf-maintenance'), allow_register: g('conf-allow-register'), allow_loans: g('conf-allow-loans') })
            });
            if (res.ok) toast.success("Security settings saved!");
            else toast.error("Failed to save security settings.");
        } catch (err) { toast.error(err.message); }
    },

    // ─── SETTINGS: ADMIN USERS ─────────────────────────────────
    async loadAdmins() {
        const admins = await this.apiFetch('/admin/admins');
        if (!admins) return;
        const tbody = document.querySelector('#admins-table tbody');
        if (!tbody) return;
        tbody.innerHTML = admins.map(a => `
            <tr>
                <td><span style="font-family:monospace;font-weight:600;color:var(--primary);">#ADM-${a.id.toString().padStart(3,'0')}</span></td>
                <td>
                    <div style="display:flex;align-items:center;gap:0.75rem;">
                        <div style="width:32px;height:32px;border-radius:50%;background:linear-gradient(135deg,#6366f1,#10b981);display:flex;align-items:center;justify-content:center;color:white;font-weight:700;font-size:0.8rem;">${a.full_name.charAt(0).toUpperCase()}</div>
                        <strong>${a.full_name}</strong>
                    </div>
                </td>
                <td>${a.email}</td>
                <td>${a.phone_number || '—'}</td>
                <td style="font-size:0.85rem;color:var(--text-muted);">${new Date(a.created_at).toLocaleDateString()}</td>
                <td><span class="badge badge-success">ACTIVE</span></td>
            </tr>`).join('') || '<tr><td colspan="6" style="text-align:center;color:var(--text-muted);padding:2rem;">No admin users found.</td></tr>';
    },

    // ─── SETTINGS: PROFILE ─────────────────────────────────────
    async loadProfileData() {
        const profile = await this.apiFetch('/admin/profile');
        if (!profile) return;
        const set = (id, val) => { const el = document.getElementById(id); if (el) el.value = val || ''; };
        set('prof-fullname', profile.full_name);
        set('prof-username', profile.username);
        set('prof-email', profile.email);
        set('prof-phone', profile.phone_number);
    },

    async updateProfile(e) {
        e.preventDefault();
        const newPass = document.getElementById('prof-new-pass')?.value;
        const confirmPass = document.getElementById('prof-confirm-pass')?.value;
        if (newPass && newPass !== confirmPass) { toast.error("New passwords do not match."); return; }

        const phone = document.getElementById('prof-phone')?.value;
        if (phone && !/^\d{10}$/.test(phone)) {
            toast.error("Phone number must be exactly 10 digits.");
            return;
        }

        const body = {
            full_name: document.getElementById('prof-fullname')?.value,
            username: document.getElementById('prof-username')?.value,
            email: document.getElementById('prof-email')?.value,
            phone_number: phone
        };
        if (newPass) { body.current_password = document.getElementById('prof-current-pass')?.value; body.new_password = newPass; }

        const res = await this.apiPut('/admin/profile', body);
        if (!res) return;
        const result = await res.json();
        if (res.ok) {
            toast.success("Profile updated successfully!");
            if (this.user) {
                this.user.username = body.username || this.user.username;
                localStorage.setItem('sacco_user', JSON.stringify(this.user));
                document.getElementById('admin-name').textContent = this.user.username;
                document.getElementById('admin-avatar').textContent = this.user.username.charAt(0).toUpperCase();
            }
            ['prof-current-pass','prof-new-pass','prof-confirm-pass'].forEach(id => { const el = document.getElementById(id); if(el) el.value=''; });
        } else { toast.error(result.error || "Profile update failed."); }
    },

    // ─── SETTINGS: SYSTEM INFO ─────────────────────────────────
    async loadSystemInfo() {
        const statusEl = document.getElementById('sys-api-status');
        try {
            const res = await fetch(`${API_BASE}/health`);
            if (statusEl) { statusEl.className = res.ok ? 'badge badge-success' : 'badge badge-danger'; statusEl.textContent = res.ok ? 'ONLINE' : 'ERROR'; }
        } catch {
            if (statusEl) { statusEl.className = 'badge badge-danger'; statusEl.textContent = 'OFFLINE'; }
        }
        const stats = await this.apiFetch('/admin/stats');
        if (stats) {
            const s = id => document.getElementById(id);
            if (s('sys-stat-users')) s('sys-stat-users').textContent = stats.total_users;
            if (s('sys-stat-savings')) s('sys-stat-savings').textContent = this.formatCurrency(stats.total_savings);
            if (s('sys-stat-shares')) s('sys-stat-shares').textContent = this.formatCurrency(stats.total_shares);
            if (s('sys-stat-loans')) s('sys-stat-loans').textContent = stats.pending_loans;
            if (s('sys-stat-disbursed')) s('sys-stat-disbursed').textContent = this.formatCurrency(stats.total_disbursed);
        }
    },

    forceLogoutAll() {
        if (!confirm("Force logout ALL admin sessions? This will also log you out.")) return;
        toast.warning("All sessions terminated. Logging out...");
        setTimeout(() => this.logout(), 2000);
    },

    exportData() {
        toast.info("Preparing data export... (Full CSV export requires server-side implementation)");
        // In production: call a dedicated export endpoint
    },

    // ─── MODALS ────────────────────────────────────────────────
    setupModalListeners() {
        const opMap = { 'op-add-member': 'register', 'op-deposit': 'deposit', 'op-withdraw': 'withdraw', 'op-apply-loan': 'loan' };
        Object.entries(opMap).forEach(([elId, modal]) =>
            document.getElementById(elId)?.addEventListener('click', () => this.openModal(modal))
        );

        document.getElementById('modal-register-form')?.addEventListener('submit', async e => {
            e.preventDefault();
            const phone = document.getElementById('m-reg-phone').value;
            if (!/^\d{10}$/.test(phone)) {
                alert('Phone number must be exactly 10 digits.');
                return;
            }
            await this.tellerRegister({
                full_name: document.getElementById('m-reg-fullname').value,
                username: document.getElementById('m-reg-username').value,
                email: document.getElementById('m-reg-email').value,
                phone_number: phone,
                password: document.getElementById('m-reg-password').value
            });
        });
        document.getElementById('modal-deposit-form')?.addEventListener('submit', async e => {
            e.preventDefault();
            await this.tellerDeposit(document.getElementById('m-dep-user-select').value, document.getElementById('m-dep-amount').value);
        });
        document.getElementById('modal-withdraw-form')?.addEventListener('submit', async e => {
            e.preventDefault();
            await this.tellerWithdraw(document.getElementById('m-with-user-select').value, document.getElementById('m-with-amount').value);
        });
        document.getElementById('modal-loan-form')?.addEventListener('submit', async e => {
            e.preventDefault();
            await this.tellerLoan(
                document.getElementById('m-loan-user-select').value, document.getElementById('m-loan-amount').value,
                document.getElementById('m-loan-months').value, document.getElementById('m-loan-reason').value
            );
        });
        window.addEventListener('keydown', e => { if (e.key === 'Escape') this.closeModals(); });
        document.getElementById('modal-container')?.addEventListener('click', e => { if (e.target.id === 'modal-container') this.closeModals(); });
    },

    openModal(type) {
        document.getElementById('modal-container')?.classList.remove('hidden');
        document.querySelectorAll('.modal-card').forEach(c => c.classList.add('hidden'));
        const cardMap = { register: 'modal-register-card', deposit: 'modal-deposit-card', withdraw: 'modal-withdraw-card', loan: 'modal-loan-card' };
        const cardId = cardMap[type];
        if (cardId) {
            document.getElementById(cardId)?.classList.remove('hidden');
            if (type === 'deposit') this.populateUserSelect('m-dep-user-select');
            if (type === 'withdraw') this.populateUserSelect('m-with-user-select');
            if (type === 'loan') this.populateUserSelect('m-loan-user-select');
        }
    },

    closeModals() {
        document.getElementById('modal-container')?.classList.add('hidden');
        document.querySelectorAll('.modal-card').forEach(c => c.classList.add('hidden'));
        ['modal-register-form','modal-deposit-form','modal-withdraw-form','modal-loan-form'].forEach(id => document.getElementById(id)?.reset());
    },

    async populateUserSelect(selectId) {
        const select = document.getElementById(selectId);
        if (!select) return;
        select.innerHTML = '<option value="" disabled selected>Loading members...</option>';
        const users = await this.apiFetch('/admin/users');
        if (!users) { select.innerHTML = '<option value="" disabled>Error loading members</option>'; return; }
        select.innerHTML = '<option value="" disabled selected>Select a Member...</option>' +
            users.map(u => `<option value="${u.id}">${u.full_name} (@${u.username} — Bal: ${this.formatCurrency(u.balance)})</option>`).join('');
    },

    // ─── TELLER OPERATIONS ─────────────────────────────────────
    async tellerRegister(data) {
        try {
            const res = await fetch(`${API_BASE}/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
            const result = await res.json();
            if (res.ok) { toast.success(`Member ${data.full_name} registered successfully!`); this.closeModals(); this.fetchPageData('dashboard'); }
            else toast.error(result.error || "Registration failed.");
        } catch (err) { toast.error("Error: " + err.message); }
    },

    async tellerDeposit(user_id, amount) {
        const res = await this.apiPost('/deposit', { user_id, amount });
        if (!res) return;
        const result = await res.json();
        if (res.ok) { toast.success(`Deposit of ${this.formatCurrency(amount)} recorded!`); this.closeModals(); this.fetchPageData(document.querySelector('.nav-link.active')?.getAttribute('data-page') || 'dashboard'); }
        else toast.error(result.error || "Deposit failed.");
    },

    async tellerWithdraw(user_id, amount) {
        const res = await this.apiPost('/withdraw', { user_id, amount });
        if (!res) return;
        const result = await res.json();
        if (res.ok) { toast.success(`Withdrawal of ${this.formatCurrency(amount)} processed!`); this.closeModals(); this.fetchPageData(document.querySelector('.nav-link.active')?.getAttribute('data-page') || 'dashboard'); }
        else toast.error(result.error || "Withdrawal failed.");
    },

    async tellerLoan(user_id, amount, duration_months, reason) {
        try {
            const res = await fetch(`${API_BASE}/loans/apply`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ user_id, amount, duration_months, reason }) });
            const result = await res.json();
            if (res.ok) { toast.success(`Loan request of ${this.formatCurrency(amount)} submitted!`); this.closeModals(); this.fetchPageData(document.querySelector('.nav-link.active')?.getAttribute('data-page') || 'dashboard'); }
            else toast.error(result.error || "Loan failed.");
        } catch (err) { toast.error("Error: " + err.message); }
    },

    // ─── SEARCH ────────────────────────────────────────────────
    setupSearchListener() {
        document.getElementById('global-search-input')?.addEventListener('input', e => {
            const q = e.target.value.toLowerCase().trim();
            document.querySelector('main section:not(.hidden)')?.querySelectorAll('tbody tr').forEach(row => {
                row.style.display = !q || row.textContent.toLowerCase().includes(q) ? '' : 'none';
            });
        });
    },

    // ─── CHARTS ────────────────────────────────────────────────
    renderCharts(stats) {
        const total = stats.total_savings + stats.total_shares;
        const el = id => document.getElementById(id);
        if (el('donut-center-total')) el('donut-center-total').textContent = this.formatCurrency(total);
        if (el('legend-savings-val')) el('legend-savings-val').textContent = this.formatCurrency(stats.total_savings);
        if (el('legend-shares-val')) el('legend-shares-val').textContent = this.formatCurrency(stats.total_shares);

        const savings = el('donut-segment-savings');
        const shares = el('donut-segment-shares');
        if (total > 0) {
            const sp = stats.total_savings / total * 440;
            const shp = stats.total_shares / total * 440;
            savings?.setAttribute('stroke-dasharray', `${sp} 440`);
            savings?.setAttribute('stroke-dashoffset', '0');
            shares?.setAttribute('stroke-dasharray', `${shp} 440`);
            shares?.setAttribute('stroke-dashoffset', `-${sp}`);
            shares?.setAttribute('transform', 'rotate(-90 90 90)');
        } else {
            savings?.setAttribute('stroke-dasharray', '0 440');
            shares?.setAttribute('stroke-dasharray', '0 440');
        }
        this.renderLineChart();
    },

    async renderLineChart() {
        const txs = await this.apiFetch('/admin/transactions');
        if (!txs || txs.length === 0) return;
        const pts = txs.slice(0, 8).reverse();
        if (!pts.length) return;
        const maxVal = Math.max(...pts.map(t => Math.abs(t.amount)), 1000);
        const W = 500, H = 150, pad = 20, cH = H - pad * 2;
        const stepX = W / (pts.length - 1 || 1);
        const points = pts.map((t, i) => ({
            x: i * stepX,
            y: H - pad - (Math.abs(t.amount) / maxVal) * cH,
            date: new Date(t.created_at)
        }));
        const pathD = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' ');
        const pathEl = document.getElementById('trends-path');
        if (pathEl) pathEl.setAttribute('d', pathD);
        const areaEl = document.getElementById('trends-area');
        if (areaEl) { const last = points[points.length - 1]; areaEl.setAttribute('d', `${pathD} L ${last.x.toFixed(1)} 148 L 0 148 Z`); }
        const labelsEl = document.getElementById('trends-labels-x');
        if (labelsEl) {
            const idxs = [0, Math.floor(points.length / 3), Math.floor(2 * points.length / 3), points.length - 1];
            labelsEl.innerHTML = points.filter((_, i) => idxs.includes(i))
                .map(p => `<span class="chart-label-x">${p.date.toLocaleDateString(undefined,{month:'short',day:'numeric'})}</span>`).join('');
        }
    }
};

document.addEventListener('DOMContentLoaded', () => app.init());
