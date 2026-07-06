document.addEventListener("DOMContentLoaded", function () {
  // 1. OS Detection
  var userAgent = navigator.userAgent || navigator.vendor || window.opera;
  var cardId = "";
  var isLinux = false;

  if (/windows/i.test(userAgent)) {
    cardId = "card-windows";
  } else if (/linux/i.test(userAgent)) {
    cardId = "card-linux";
    isLinux = true;
  }

  if (cardId) {
    var card = document.getElementById(cardId);
    if (card) {
      card.classList.add("detected");
      var badge = document.createElement("div");
      badge.className = "detected-badge";
      badge.innerText = "Suggested for you";
      card.appendChild(badge);
    }
  }

  // Show Linux quick install box if user is on Linux
  if (isLinux) {
    var linuxBox = document.getElementById("linux-quick-install-box");
    if (linuxBox) {
      linuxBox.style.display = "block";
    }
  }

  // 2. Fetch latest version from distribution repository
  var latestJsonUrl = "https://raw.githubusercontent.com/immo2n/TuneLister-dist/refs/heads/main/latest.json?t=" + Date.now();

  fetch(latestJsonUrl)
    .then(function (res) {
      if (!res.ok) throw new Error("Failed to load latest.json");
      return res.json();
    })
    .then(function (data) {
      var versionStr = data.version + "-" + data.build_name;
      
      // Update version tag
      var versionTag = document.getElementById("version-tag");
      if (versionTag) versionTag.innerText = versionStr;

      var banner = document.getElementById("version-banner");
      if (banner) banner.style.display = "inline-block";

      // Update download links with version parameter
      updateDownloadUrls(versionStr);
    })
    .catch(function (err) {
      console.error("Error loading latest.json:", err);
      // Fallback version
      var fallbackVer = "1.0.0-stable";
      var versionTag = document.getElementById("version-tag");
      if (versionTag) versionTag.innerText = fallbackVer;

      var banner = document.getElementById("version-banner");
      if (banner) banner.style.display = "inline-block";
      
      updateDownloadUrls(fallbackVer);
    });

  // Helper to replace placeholder versions in links
  function updateDownloadUrls(versionStr) {
    var links = document.querySelectorAll(".btn-download, .cli-link");
    links.forEach(function (link) {
      var href = link.getAttribute("href");
      if (href) {
        var newHref = href.replace("1.0.0-stable", versionStr);
        link.setAttribute("href", newHref);
      }
    });
  }

  // 3. Copy to clipboard helper
  window.copyText = function (text, btn) {
    navigator.clipboard.writeText(text).then(function () {
      var originalHTML = btn.innerHTML;
      btn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5" style="width: 14px; height: 14px; display: inline-block; vertical-align: middle; margin-right: 4px;"><polyline points="20 6 9 17 4 12"></polyline></svg><span style="vertical-align: middle;">Done</span>';
      btn.style.background = "#1db954";
      btn.style.borderColor = "#1db954";
      btn.style.color = "#000000";
      setTimeout(function () {
        btn.innerHTML = originalHTML;
        btn.style.background = "";
        btn.style.borderColor = "";
        btn.style.color = "";
      }, 1500);
    }).catch(function (err) {
      console.error("Failed to copy text:", err);
    });
  };

  // 4. Smooth FAQ Collapse/Expand
  var faqItems = document.querySelectorAll(".faq-item");
  faqItems.forEach(function (item) {
    var question = item.querySelector("h3");
    question.style.cursor = "pointer";
    question.addEventListener("click", function () {
      // Toggle active class
      var wasActive = item.classList.contains("active");
      
      // Close all first for accordion behavior (optional, let's allow multi open)
      // faqItems.forEach(function(i) { i.classList.remove("active"); });
      
      if (!wasActive) {
        item.classList.add("active");
      } else {
        item.classList.remove("active");
      }
    });
  });

  // 5. Prevent zoom events for native feel
  document.addEventListener('touchstart', function (event) {
    if (event.touches.length > 1) {
      event.preventDefault();
    }
  }, { passive: false });

  var lastTouchEnd = 0;
  document.addEventListener('touchend', function (event) {
    var now = (new Date()).getTime();
    if (now - lastTouchEnd <= 300) {
      event.preventDefault();
    }
    lastTouchEnd = now;
  }, false);

  document.addEventListener('gesturestart', function (event) {
    event.preventDefault();
  });

  // Windows SmartScreen Defender Warning Dialog Logic
  var defenderModal = document.getElementById("defender-modal");

  document.body.addEventListener("click", function (event) {
    var anchor = event.target.closest("a");
    if (anchor && anchor.getAttribute("href") && anchor.getAttribute("href").includes("TuneLister-Installer.exe")) {
      // Allow download to start instantly, and show the instructional dialog alongside it
      if (defenderModal) {
        defenderModal.classList.add("active");
      }
    }
  });

  var closeButtons = ["defender-cancel", "defender-ok-btn", "defender-close-btn"];
  closeButtons.forEach(function (id) {
    var el = document.getElementById(id);
    if (el) {
      el.addEventListener("click", function () {
        if (defenderModal) {
          defenderModal.classList.remove("active");
        }
      });
    }
  });
});
