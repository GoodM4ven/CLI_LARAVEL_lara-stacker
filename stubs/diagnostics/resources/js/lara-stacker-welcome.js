import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

window.Pusher = Pusher;

const createEcho = () => {
    if (window.Echo) {
        return window.Echo;
    }

    const scheme = import.meta.env.VITE_REVERB_SCHEME || 'https';
    const port = Number(import.meta.env.VITE_REVERB_PORT || (scheme === 'https' ? 443 : 80));

    return (window.Echo = new Echo({
        broadcaster: 'reverb',
        key: import.meta.env.VITE_REVERB_APP_KEY,
        wsHost: import.meta.env.VITE_REVERB_HOST,
        wsPort: port,
        wssPort: port,
        forceTLS: scheme === 'https',
        enabledTransports: ['ws', 'wss'],
    }));
};

const bootWelcomePing = () => {
    const button = document.querySelector('[data-lara-stacker-ping]');
    const status = document.querySelector('[data-lara-stacker-ping-status]');
    const box = document.querySelector('[data-lara-stacker-ping-box]');

    if (!button || !status || !box) {
        return;
    }

    const pageId = crypto.randomUUID?.() || `${Date.now()}-${Math.random()}`;
    const sender = window.location.hostname || 'welcome page';
    const setStatus = (message, highlight = false) => {
        status.textContent = message;
        box.classList.toggle('border-[#f53003]', highlight);
        box.classList.toggle('dark:border-[#FF4433]', highlight);
    };

    try {
        createEcho().channel('lara-stacker.welcome').listen('.lara-stacker.welcome-ping', (event) => {
            if (event.pageId === pageId) {
                return;
            }

            setStatus(`${event.sender || 'Another page'} sent a ping · ${new Date().toLocaleTimeString()}`, true);
            window.setTimeout(() => setStatus('Waiting for another welcome page'), 2400);
        });
    } catch (error) {
        setStatus('Reverb is not connected');
        console.warn('Lara-Stacker welcome ping could not start.', error);
    }

    button.addEventListener('click', async () => {
        button.disabled = true;
        setStatus('Pinging open pages…');

        try {
            const response = await fetch(button.dataset.url, {
                method: 'POST',
                headers: {
                    Accept: 'application/json',
                    'Content-Type': 'application/json',
                    'X-Requested-With': 'XMLHttpRequest',
                },
                body: JSON.stringify({
                    _diagnostics_token: button.dataset.token,
                    sender,
                    message: 'Lara-Stacker welcome ping',
                    page_id: pageId,
                }),
            });

            if (!response.ok) {
                throw new Error(`Ping failed with HTTP ${response.status}`);
            }

            setStatus('Ping sent · waiting for replies', true);
        } catch (error) {
            setStatus('Ping failed; check Reverb and the browser console');
            console.warn('Lara-Stacker welcome ping failed.', error);
        } finally {
            window.setTimeout(() => {
                button.disabled = false;
            }, 700);
        }
    });
};

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bootWelcomePing, { once: true });
} else {
    bootWelcomePing();
}
