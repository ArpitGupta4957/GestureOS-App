<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MyDial - The Future of Control</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <!-- FontAwesome for Icons -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        primary: '#00ff9d',
                        secondary: '#7000ff',
                        dark: '#050505',
                        surface: '#121212',
                    },
                    fontFamily: {
                        sans: ['Inter', 'sans-serif'],
                    },
                    animation: {
                        'float': 'float 6s ease-in-out infinite',
                        'pulse-slow': 'pulse 4s cubic-bezier(0.4, 0, 0.6, 1) infinite',
                        'fade-in-up': 'fadeInUp 0.8s ease-out forwards',
                        'slide-in': 'slideIn 0.5s ease-out forwards',
                    },
                    keyframes: {
                        float: {
                            '0%, 100%': { transform: 'translateY(0)' },
                            '50%': { transform: 'translateY(-20px)' },
                        },
                        fadeInUp: {
                            '0%': { opacity: '0', transform: 'translateY(20px)' },
                            '100%': { opacity: '1', transform: 'translateY(0)' },
                        },
                        slideIn: {
                            '0%': { opacity: '0', transform: 'translateX(-20px)' },
                            '100%': { opacity: '1', transform: 'translateX(0)' },
                        }
                    }
                }
            }
        }
    </script>
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #050505; color: white; overflow-x: hidden; }
        .neon-text { text-shadow: 0 0 10px rgba(0, 255, 157, 0.5); }
        .hero-gradient { background: radial-gradient(circle at center, rgba(112, 0, 255, 0.15) 0%, rgba(5, 5, 5, 0) 70%); }
        .glass-nav { background: rgba(5, 5, 5, 0.8); backdrop-filter: blur(12px); border-bottom: 1px solid rgba(255, 255, 255, 0.05); }
        
        .feature-card { 
            transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1); 
            border: 1px solid rgba(255,255,255,0.05); 
            background: linear-gradient(145deg, #1a1a1a 0%, #0a0a0a 100%);
        }
        .feature-card:hover { 
            transform: translateY(-10px) scale(1.02); 
            border-color: #00ff9d; 
            box-shadow: 0 10px 30px -10px rgba(0, 255, 157, 0.2); 
        }

        /* Animated Background Mesh */
        .bg-mesh {
            position: absolute;
            width: 100%;
            height: 100%;
            top: 0;
            left: 0;
            overflow: hidden;
            z-index: -1;
        }
        .blob {
            position: absolute;
            filter: blur(80px);
            opacity: 0.4;
            animation: float 10s infinite ease-in-out alternate;
        }
        .blob-1 { top: 10%; left: 20%; width: 300px; height: 300px; background: #7000ff; animation-delay: 0s; }
        .blob-2 { bottom: 20%; right: 10%; width: 400px; height: 400px; background: #00ff9d; animation-delay: -5s; }
        .blob-3 { top: 40%; left: 60%; width: 200px; height: 200px; background: #ff0055; animation-delay: -2s; opacity: 0.2; }

    </style>
</head>
<body class="antialiased selection:bg-primary selection:text-black">

    <div class="bg-mesh">
        <div class="blob blob-1"></div>
        <div class="blob blob-2"></div>
        <div class="blob blob-3"></div>
    </div>

    <!-- Navigation -->
    <nav class="flex items-center justify-between px-6 py-4 md:px-12 fixed w-full top-0 z-50 glass-nav animate-slide-in">
        <div class="text-2xl font-bold tracking-tighter flex items-center gap-2 group cursor-pointer">
            <i class="fa-solid fa-wand-magic-sparkles text-primary group-hover:rotate-12 transition-transform"></i>
            <span>My<span class="text-primary neon-text">Dial</span></span>
        </div>
        <div class="hidden md:flex gap-8 text-sm font-medium text-gray-400">
            <a href="#features" class="hover:text-white transition-colors relative group">
                Features
                <span class="absolute -bottom-1 left-0 w-0 h-0.5 bg-primary transition-all group-hover:w-full"></span>
            </a>
            <a href="#how-it-works" class="hover:text-white transition-colors relative group">
                How it Works
                <span class="absolute -bottom-1 left-0 w-0 h-0.5 bg-primary transition-all group-hover:w-full"></span>
            </a>
        </div>
        <a href="#download" class="bg-white text-black px-6 py-2 rounded-full font-bold text-sm hover:bg-primary hover:text-black transition-all transform hover:scale-105 shadow-lg">
            Get Started
        </a>
    </nav>

    <!-- Hero Section -->
    <section class="min-h-screen flex flex-col justify-center items-center text-center px-4 pt-24 relative overflow-hidden">
        
        <div class="animate-fade-in-up" style="animation-delay: 0.1s;">
            <span class="px-3 py-1 rounded-full border border-primary/30 text-primary text-xs font-mono uppercase tracking-widest bg-primary/10 mb-6 inline-block">
                v1.0.0 Stable Release
            </span>
        </div>

        <h1 class="text-5xl md:text-8xl font-black tracking-tight mb-6 leading-tight z-10 animate-fade-in-up" style="animation-delay: 0.2s;">
            Control Your World <br>
            <span class="text-transparent bg-clip-text bg-gradient-to-r from-primary via-white to-secondary animate-pulse-slow">With a Gesture</span>
        </h1>
        
        <p class="text-gray-400 text-lg md:text-xl max-w-2xl mb-10 z-10 animate-fade-in-up" style="animation-delay: 0.3s;">
            Draw on your screen to launch apps, make calls, and automate tasks. 
            The ultimate productivity tool for power users.
        </p>
        
        <div class="flex flex-col md:flex-row gap-4 z-10 animate-fade-in-up" style="animation-delay: 0.4s;">
            <!-- Android Button -->
            <a href="#download" onclick="alert('Please ensure app-release.apk is in public/downloads/')" class="group relative px-8 py-4 bg-transparent border-2 border-white rounded-xl font-bold text-white overflow-hidden transition-all hover:border-primary hover:text-black">
                <div class="absolute inset-0 w-0 bg-primary transition-all duration-[250ms] ease-out group-hover:w-full"></div>
                <div class="relative flex items-center justify-center gap-3">
                    <i class="fa-brands fa-android text-2xl"></i>
                    <div class="text-left leading-tight">
                        <div class="text-[10px] uppercase tracking-wider opacity-80">Download for</div>
                        <div class="text-lg">Android</div>
                    </div>
                </div>
            </a>

            <!-- iOS Button -->
            <button onclick="alert('iOS Version Coming Soon!')" class="group relative px-8 py-4 bg-transparent border-2 border-gray-700 rounded-xl font-bold text-gray-500 overflow-hidden transition-all hover:border-gray-500 hover:text-gray-300">
                <div class="relative flex items-center justify-center gap-3">
                    <i class="fa-brands fa-apple text-2xl"></i>
                    <div class="text-left leading-tight">
                        <div class="text-[10px] uppercase tracking-wider opacity-80">Download for</div>
                        <div class="text-lg">iOS (Soon)</div>
                    </div>
                </div>
            </button>
        </div>

        <!-- Floating Mockup -->
        <div class="mt-20 relative z-10 animate-float">
            <div class="w-72 h-auto border-[6px] border-gray-800 rounded-[3rem] bg-black p-2 shadow-2xl mx-auto ring-1 ring-white/10">
                <div class="bg-gray-900 rounded-[2.5rem] overflow-hidden h-full aspect-[9/19] relative">
                    <!-- Screen Gradient -->
                    <div class="absolute inset-0 bg-gradient-to-br from-gray-800 to-black"></div>
                    
                    <!-- App UI Mockup -->
                    <div class="absolute inset-0 flex flex-col items-center justify-center p-6">
                        <div class="w-16 h-16 rounded-2xl bg-gradient-to-tr from-primary to-secondary mb-6 flex items-center justify-center shadow-lg shadow-primary/20">
                             <i class="fa-solid fa-wand-magic-sparkles text-white text-2xl"></i>
                        </div>
                        <div class="w-full h-2 bg-gray-700 rounded-full mb-2 opacity-50"></div>
                        <div class="w-2/3 h-2 bg-gray-700 rounded-full mb-8 opacity-30"></div>
                        
                        <!-- Overlay Element -->
                         <div class="absolute bottom-10 left-4 right-4 bg-white/10 backdrop-blur-lg border border-white/10 rounded-xl p-4 transform rotate-1">
                            <div class="flex items-center gap-3">
                                <div class="w-8 h-8 rounded-full bg-green-500 flex items-center justify-center text-xs">
                                    <i class="fa-brands fa-whatsapp text-white"></i>
                                </div>
                                <div class="text-left">
                                    <div class="text-xs text-primary font-mono">GESTURE DETECTED</div>
                                    <div class="text-sm font-bold text-white">Opening WhatsApp...</div>
                                </div>
                            </div>
                         </div>
                    </div>
                    
                    <!-- Reflection -->
                    <div class="absolute inset-0 bg-gradient-to-tr from-transparent via-white/5 to-transparent pointer-events-none"></div>
                </div>
            </div>
            <!-- Glow under phone -->
            <div class="absolute -bottom-10 left-1/2 -translate-x-1/2 w-40 h-40 bg-primary/20 blur-[50px] rounded-full -z-10"></div>
        </div>
    </section>

    <!-- Features Grid -->
    <section id="features" class="py-32 px-6 md:px-12 bg-surface relative">
        <div class="max-w-7xl mx-auto">
            <div class="text-center mb-20">
                <h2 class="text-3xl md:text-5xl font-bold mb-4 font-sans">Why MyDial?</h2>
                <p class="text-gray-400 max-w-xl mx-auto">Designed for speed, built for efficiency. Experience the next level of mobile interaction.</p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
                <!-- Feature 1 -->
                <div class="feature-card p-8 rounded-3xl">
                    <div class="w-14 h-14 bg-gradient-to-br from-primary/20 to-transparent rounded-2xl flex items-center justify-center mb-6 text-primary border border-primary/20">
                        <i class="fa-solid fa-rocket text-2xl"></i>
                    </div>
                    <h3 class="text-2xl font-bold mb-3">Instant Actions</h3>
                    <p class="text-gray-400 leading-relaxed">Launch any app or shortcut instantly by drawing a simple shape on your screen. No more scrolling.</p>
                </div>

                <!-- Feature 2 -->
                <div class="feature-card p-8 rounded-3xl">
                    <div class="w-14 h-14 bg-gradient-to-br from-secondary/20 to-transparent rounded-2xl flex items-center justify-center mb-6 text-secondary border border-secondary/20">
                        <i class="fa-solid fa-phone-volume text-2xl"></i>
                    </div>
                    <h3 class="text-2xl font-bold mb-3">Smart Dialer</h3>
                    <p class="text-gray-400 leading-relaxed">Bulk dial numbers from Excel or OCR efficiently. Perfect for power professionals and businesses.</p>
                </div>

                <!-- Feature 3 -->
                <div class="feature-card p-8 rounded-3xl">
                    <div class="w-14 h-14 bg-gradient-to-br from-pink-500/20 to-transparent rounded-2xl flex items-center justify-center mb-6 text-pink-500 border border-pink-500/20">
                        <i class="fa-solid fa-shield-halved text-2xl"></i>
                    </div>
                    <h3 class="text-2xl font-bold mb-3">Privacy First</h3>
                    <p class="text-gray-400 leading-relaxed">Your data stays on your device. We prioritize security and data integrity above all else.</p>
                </div>
            </div>
        </div>
    </section>

    <!-- Footer -->
    <footer class="py-12 bg-black border-t border-white/5 relative overflow-hidden">
        <div class="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-4xl h-px bg-gradient-to-r from-transparent via-primary/50 to-transparent"></div>
        <div class="max-w-7xl mx-auto px-6 flex flex-col md:flex-row justify-between items-center gap-6">
            <div class="text-2xl font-bold tracking-tighter">
                My<span class="text-primary neon-text">Dial</span>
            </div>
            <div class="text-gray-500 text-sm">
                &copy; 2024 MyDial Inc. All rights reserved.
            </div>
            <div class="flex gap-6">
                <a href="#" class="text-gray-500 hover:text-white transition-colors"><i class="fa-brands fa-twitter text-xl"></i></a>
                <a href="#" class="text-gray-500 hover:text-white transition-colors"><i class="fa-brands fa-github text-xl"></i></a>
                <a href="#" class="text-gray-500 hover:text-white transition-colors"><i class="fa-brands fa-instagram text-xl"></i></a>
            </div>
        </div>
    </footer>

</body>
</html>
