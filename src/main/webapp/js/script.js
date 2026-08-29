// ============================================================
// Backpackr - shared client-side helpers
// ============================================================

function showToast(message) {
    const toast = document.getElementById('toast');
    if (!toast) return;
    toast.textContent = message;
    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), 2500);
}

// Add a place to a trip without leaving the current page.
// tripId may be null - the server will create/use a default trip.
function addToTrip(placeId, tripId, buttonEl) {
    const params = new URLSearchParams();
    params.set('action', 'addStopAjax');
    params.set('placeId', placeId);
    if (tripId !== null && tripId !== undefined && tripId !== 'null') {
        params.set('tripId', tripId);
    }

    fetch('trip', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params.toString()
    })
        .then(res => res.json())
        .then(data => {
            if (data.success) {
                showToast('Added to your trip ✈️');
                if (buttonEl) {
                    const original = buttonEl.textContent;
                    buttonEl.textContent = '✔ Added';
                    setTimeout(() => { buttonEl.textContent = original; }, 1500);
                }
            } else {
                showToast(data.message || 'Could not add to trip');
            }
        })
        .catch(() => showToast('Network error - please try again'));
}

// Toggle a saved/bookmarked place.
function toggleSave(buttonEl, placeId) {
    const params = new URLSearchParams();
    params.set('placeId', placeId);

    fetch('save', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params.toString()
    })
        .then(res => res.json())
        .then(data => {
            if (data.success) {
                if (data.saved) {
                    buttonEl.classList.add('saved');
                    buttonEl.textContent = '🔖';
                    showToast('Saved for later');
                } else {
                    buttonEl.classList.remove('saved');
                    buttonEl.textContent = '📑';
                    showToast('Removed from saved places');
                }
            } else {
                showToast(data.message || 'Could not update saved places');
            }
        })
        .catch(() => showToast('Network error - please try again'));
}

// Submit (or update) a 1-5 star community rating for a place.
function submitRating(placeId, stars, starEl) {
    const params = new URLSearchParams();
    params.set('placeId', placeId);
    params.set('stars', stars);

    fetch('rate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params.toString()
    })
        .then(res => res.json())
        .then(data => {
            if (data.success) {
                const row = starEl.closest('.rating-row');
                if (row) {
                    const starEls = row.querySelectorAll('.star');
                    starEls.forEach((el, idx) => {
                        el.classList.toggle('filled', idx < Math.round(data.avgRating));
                    });
                    const countEl = row.querySelector('.rating-count');
                    if (countEl) {
                        countEl.textContent = data.avgRating.toFixed(1) + ' (' + data.ratingCount + ')';
                    }
                }
                showToast('Thanks for rating!');
            } else {
                showToast(data.message || 'Could not save your rating');
            }
        })
        .catch(() => showToast('Network error - please try again'));
}
