// Tab switching
document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        // Remove active class from all buttons and contents
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));

        // Add active class to clicked button and corresponding content
        btn.classList.add('active');
        const tabId = btn.getAttribute('data-tab');
        document.getElementById(tabId).classList.add('active');
    });
});

// Live API evidence
async function loadModels() {
    const modelsList = document.getElementById('models-list');
    try {
        const response = await fetch('https://gen.pollinations.ai/text/models');
        if (!response.ok) throw new Error('API request failed');
        const data = await response.json();
        if (data.data && Array.isArray(data.data)) {
            const models = data.data.slice(0, 10).map(m => m.id || m.name || JSON.stringify(m));
            modelsList.textContent = models.join('\n');
        } else {
            modelsList.textContent = JSON.stringify(data, null, 2);
        }
    } catch (err) {
        modelsList.textContent = 'Error loading models: ' + err.message;
    }
}

async function testChatEndpoint() {
    const chatEvidence = document.getElementById('chat-evidence');
    try {
        const response = await fetch('https://gen.pollinations.ai/v1/chat/completions', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                model: 'openai/gpt-5.4-nano',
                messages: [{ role: 'user', content: 'Say hello in one sentence.' }],
                max_tokens: 50,
            }),
        });
        if (!response.ok) throw new Error('API request failed: ' + response.status);
        const data = await response.json();
        if (data.choices && data.choices[0]) {
            chatEvidence.textContent = 'Response: ' + data.choices[0].message.content;
        } else {
            chatEvidence.textContent = JSON.stringify(data, null, 2);
        }
    } catch (err) {
        chatEvidence.textContent = 'Error: ' + err.message;
    }
}

// Load evidence on page load
document.addEventListener('DOMContentLoaded', () => {
    loadModels();
    // Test chat endpoint after a short delay
    setTimeout(testChatEndpoint, 1000);
});

// Smooth scroll for nav links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    });
});
