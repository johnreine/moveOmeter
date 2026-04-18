// Analytics tracking for moveOmeter Web Dashboard
// Tracks user sessions, logins, and actions

class AnalyticsService {
    constructor(supabaseClient) {
        this.db = supabaseClient;
        this.sessionId = null;
        this.userId = null;
        this.sessionStartTime = null;
        this.pageViews = 0;
        this.actionsCount = 0;

        // Track page visibility for accurate session duration
        this.isPageVisible = true;
        this.setupVisibilityTracking();
    }

    // Initialize analytics session
    async initSession(userId) {
        this.userId = userId;
        this.sessionStartTime = new Date();

        try {
            // Collect browser/device info
            const sessionData = {
                user_id: userId,
                session_start: this.sessionStartTime.toISOString(),
                ip_address: await this.getIPAddress(),
                user_agent: navigator.userAgent,
                browser: this.getBrowserName(),
                os: this.getOSName(),
                device_type: this.getDeviceType(),
                screen_resolution: `${window.screen.width}x${window.screen.height}`,
                page_views: 0,
                actions_count: 0
            };

            const { data, error } = await this.db
                .from('user_sessions')
                .insert(sessionData)
                .select()
                .single();

            if (error) {
                console.error('Error creating analytics session:', error);
                return;
            }

            this.sessionId = data.id;
            console.log('📊 Analytics session started:', this.sessionId);

            // Track initial page view
            this.trackPageView(window.location.pathname);

        } catch (err) {
            console.error('Exception initializing analytics:', err);
        }
    }

    // End session and record duration
    async endSession() {
        if (!this.sessionId) return;

        try {
            const sessionEnd = new Date();
            const duration = Math.floor((sessionEnd - this.sessionStartTime) / 1000);

            await this.db
                .from('user_sessions')
                .update({
                    session_end: sessionEnd.toISOString(),
                    duration_seconds: duration,
                    page_views: this.pageViews,
                    actions_count: this.actionsCount
                })
                .eq('id', this.sessionId);

            console.log('📊 Analytics session ended. Duration:', duration, 'seconds');
        } catch (err) {
            console.error('Error ending analytics session:', err);
        }
    }

    // Track user action
    async trackAction(actionType, actionCategory, actionTarget, actionValue = null) {
        if (!this.sessionId || !this.userId) return;

        this.actionsCount++;

        try {
            await this.db
                .from('user_actions')
                .insert({
                    user_id: this.userId,
                    session_id: this.sessionId,
                    action_type: actionType,
                    action_category: actionCategory,
                    action_target: actionTarget,
                    action_value: actionValue,
                    page_url: window.location.href,
                    referrer: document.referrer
                });

            // Update session actions count
            await this.db
                .from('user_sessions')
                .update({ actions_count: this.actionsCount })
                .eq('id', this.sessionId);

        } catch (err) {
            console.error('Error tracking action:', err);
        }
    }

    // Track page view
    async trackPageView(pagePath) {
        this.pageViews++;
        await this.trackAction('page_view', 'navigation', pagePath);
    }

    // Track button click
    async trackButtonClick(buttonName, category = 'interaction') {
        await this.trackAction('button_click', category, buttonName);
    }

    // Track chart interaction
    async trackChartInteraction(chartName, interactionType) {
        await this.trackAction('chart_interaction', 'data_view', chartName, interactionType);
    }

    // Track device view
    async trackDeviceView(deviceId) {
        await this.trackAction('device_view', 'device_management', deviceId);
    }

    // Track mode switch (sleep/fall detection)
    async trackModeSwitch(newMode) {
        await this.trackAction('mode_switch', 'settings', 'operational_mode', newMode);
    }

    // Track annotation creation
    async trackAnnotationCreate(annotationType) {
        await this.trackAction('annotation_create', 'data_annotation', annotationType);
    }

    // Setup page visibility tracking
    setupVisibilityTracking() {
        document.addEventListener('visibilitychange', () => {
            this.isPageVisible = !document.hidden;

            if (document.hidden) {
                // Page hidden - update session
                this.updateSessionMetrics();
            }
        });

        // Track session end on page unload
        window.addEventListener('beforeunload', () => {
            this.endSession();
        });
    }

    // Update session metrics periodically
    async updateSessionMetrics() {
        if (!this.sessionId) return;

        try {
            await this.db
                .from('user_sessions')
                .update({
                    page_views: this.pageViews,
                    actions_count: this.actionsCount
                })
                .eq('id', this.sessionId);
        } catch (err) {
            console.error('Error updating session metrics:', err);
        }
    }

    // Get IP address (using public API)
    async getIPAddress() {
        try {
            const response = await fetch('https://api.ipify.org?format=json');
            const data = await response.json();
            return data.ip;
        } catch {
            return 'unknown';
        }
    }

    // Detect browser name
    getBrowserName() {
        const ua = navigator.userAgent;
        if (ua.includes('Chrome')) return 'Chrome';
        if (ua.includes('Firefox')) return 'Firefox';
        if (ua.includes('Safari')) return 'Safari';
        if (ua.includes('Edge')) return 'Edge';
        return 'Other';
    }

    // Detect OS name
    getOSName() {
        const ua = navigator.userAgent;
        if (ua.includes('Win')) return 'Windows';
        if (ua.includes('Mac')) return 'macOS';
        if (ua.includes('Linux')) return 'Linux';
        if (ua.includes('Android')) return 'Android';
        if (ua.includes('iOS')) return 'iOS';
        return 'Other';
    }

    // Detect device type
    getDeviceType() {
        const ua = navigator.userAgent;
        if (/(tablet|ipad|playbook|silk)|(android(?!.*mobi))/i.test(ua)) {
            return 'tablet';
        }
        if (/Mobile|Android|iP(hone|od)|IEMobile|BlackBerry|Kindle|Silk-Accelerated|(hpw|web)OS|Opera M(obi|ini)/.test(ua)) {
            return 'mobile';
        }
        return 'desktop';
    }
}

// Global analytics instance (initialized after login)
let analytics = null;
let analyticsIntervalId = null;

// Cleanup analytics (Fix for memory leaks)
function cleanupAnalytics() {
    if (analyticsIntervalId) {
        clearInterval(analyticsIntervalId);
        analyticsIntervalId = null;
    }
    if (analytics) {
        try {
            analytics.endSession().catch(err => {
                console.error('Error ending analytics session:', err);
            });
        } catch (err) {
            console.error('Error during analytics cleanup:', err);
        }
        analytics = null;
    }
}

// Initialize analytics after user logs in
function initializeAnalytics(supabaseClient, userId) {
    try {
        // Clean up old analytics first (prevent memory leaks)
        cleanupAnalytics();

        analytics = new AnalyticsService(supabaseClient);
        analytics.initSession(userId);

        // Update metrics every 30 seconds
        analyticsIntervalId = setInterval(() => {
            if (analytics) {
                try {
                    analytics.updateSessionMetrics().catch(err => {
                        console.error('Error updating analytics metrics:', err);
                    });
                } catch (err) {
                    console.error('Error in analytics metrics update:', err);
                }
            }
        }, 30000);

        console.log('✅ Analytics initialized');
    } catch (err) {
        console.error('❌ Analytics initialization failed:', err);
        // Continue without analytics - don't crash the app
        analytics = null;
    }
}

// Cleanup on page unload
window.addEventListener('beforeunload', cleanupAnalytics);

// Helper function to track action (can be called from anywhere)
function trackAction(actionType, actionCategory, actionTarget, actionValue = null) {
    try {
        if (analytics) {
            analytics.trackAction(actionType, actionCategory, actionTarget, actionValue);
        }
    } catch (err) {
        console.error('Analytics tracking failed:', err);
        // Don't crash the app if analytics fails
    }
}
