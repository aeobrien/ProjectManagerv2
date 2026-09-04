# QRosity

## Version History
- v1.0 – 2025-06-14 – Initial build completed with dynamic quote selection and UI.
    
- v1.1 – [TBD] – Bug fixes for border rendering and button visibility on load.
    

---
## Core Concept
**QRosity** is a digital curiosity engine—a minimalist, serendipitous art project that invites users to scan a QR code placed in the real world. In doing so, they're taken to [QRosity.com](https://qrosity.com/), where they're rewarded with a short quote, fact, poem, or other unexpected gem. The content rotates randomly with each refresh. The website frames the quote in a lightly imperfect, hand-drawn-style border, intended to soften the screen-based interaction and evoke a more human, analogue sensibility. It's a not-for-purpose initiative under the umbrella of **Artifact.ing**, focused on rewarding curiosity with serendipity and insight.

---
## Tags
#App #Creative #Art #Physical
## Guiding Principles & Intentions
- **Celebrate curiosity**: Make scanning a random QR code an act of delightful discovery.
    
- **Minimal and beautiful**: Prioritise simplicity and elegance in both design and copy.
    
- **Not-for-purpose**: Resist the instinct to commercialise or gamify; QRosity is a gift, not a product.
    
- **Tactile-meets-digital**: Use real-world placement to bridge analogue and digital experiences.
    
- **Encourage slow thinking**: Provide a single quote per load with no scroll, no feed, no distractions.
    

---
## Key Features & Functionality
- **Dynamic Quote Selection**
    
    - 700+ curated quotes stored in a MySQL database
        
    - Random selection on page load or refresh
        
    - One quote shown at a time; no scrolling or backtracking
        
- **Imperfect Frame Rendering**
    
    - Each quote is enclosed in a dynamically drawn, slightly wonky hand-style frame
        
    - Border sizing adjusts to screen and quote dimensions
        
    - Wobble algorithm ensures each render feels human and different
        
- **Minimal UI**
    
    - Refresh button (🔄) loads a new quote
        
    - Info button (❓) opens a modal explaining the project
        
- **QR Code Access**
    
    - Visitors arrive by scanning a custom-designed QR code sticker
        
    - No other traffic source anticipated—intentionally ephemeral and discoverable
        
- **Mobile-first Design**
    
    - Fully responsive for mobile, as the primary use case is smartphone access in the wild
        

---
## Architecture & Structure
### Frontend

- HTML/CSS/JavaScript (vanilla or light framework)
    
- Canvas-based border drawing script
    
- Modal overlay for project explanation
    
- Responsive layout targeting small screens
    

### Backend

- MySQL database of quotes (pre-loaded with ~700 entries)
    
- PHP or serverless function to randomly select and serve a quote
    

### Hosting & Domain

- Domain: [QRosity.com](https://qrosity.com/) (registered)
    
- Hosted on standard web hosting (TBD CDN or caching layer)
    

---
## Implementation Roadmap
### Phase 1: Build & Core Functionality

-  Build database and connect dynamic quote retrieval
    
-  Implement canvas-based border drawing with randomised imperfections
    
-  Build modal for project explanation
    
-  Design minimalist UI with refresh and info buttons
    

### Phase 2: Polish & Fixes

-  Fix border rendering bug (excessive wobble magnitude)
    
-  Fix load-time visibility issue for refresh/info buttons
    
-  Improve performance/responsiveness of frame drawing on slow devices
    

### Phase 3: QR Design & Deployment

-  Design visually striking, custom QR code
    
-  Order sticker print run (size, material, quantity TBD)
    
-  Distribute stickers in curated real-world locations
    

### Phase 4: Maintenance & Expansion (Optional)

-  Add quote categorisation (humour, philosophy, poetry, etc.)
    
-  Add seasonal/rotating themes (e.g. solstice, anniversaries)
    
-  Option to “favourite” or save quote (only if it adds real value)
    

---
## Current Status & Progress

## Next Steps
- [ ] Quote manager not saving changes when not in inbox mode
- [ ] Create better poem adding pipeline
- [ ] Add more poems
- [ ] Incorporate poems
- [x] Investigate border rendering code and recalibrate wobble parameters
- [ ] Debug page-load issue causing missing buttons
- [ ] Design experimental QR codes that retain scannability while adding aesthetic flair
- [ ] Source and order high-quality stickers
- [ ] Plan initial sticker drop locations
- [ ] Implement JS backup for border drawing https://chatgpt.com/c/6859c32c-f760-8011-87ee-daae729389c7
## Challenges & Solutions
|Challenge|Proposed / Active Solution|
|---|---|
|Canvas border wobble too exaggerated|Re-examine noise/random functions and border sizing logic|
|Refresh/info buttons don’t render on initial load|Delay rendering until after page load or explicitly trigger with DOMContentLoaded|
|QR codes often look generic and uninviting|Use visual layering, background blending, or embedded iconography (e.g. eye, spiral, glyph) while testing with multiple QR code scanners|
|Users may not understand purpose of site on first visit|Keep modal copy concise but evocative; test variants if confusion persists|
|Stickers may be removed from public spaces|Choose locations mindfully; consider collaborations with venues or events|

---
## User/Audience Experience
The ideal encounter goes something like this:

> A curious person notices a strange-looking QR sticker.  
> They scan it. A clean, calming site loads.  
> They’re shown a quote—clever, beautiful, unexpected.  
> There are no ads, no products, no agenda.  
> Just the invitation to reflect—or refresh for another.  
> A moment of human strangeness and beauty on an ordinary day.

The project relies on the surprise and delight of physical-world discovery and minimalist digital reward. It asks for nothing and offers only curiosity in return.

---
## Success Metrics
- Stickers scanned (via analytics or URL tracking)
    
- Quotes refreshed per visit (optional metric)
    
- Organic shares or mentions (e.g. Instagram stories, blog posts)
    
- Emotional response: "This made my day", "What is this?", etc.
    
- Long-term: potential to be referenced in discussions about ambient art, lo-fi interaction, or digital minimalism
    

---
## Research & References
- [LoQR](https://www.nngroup.com/articles/qr-code-usability/) — Nielsen Norman Group usability notes
    
- [Sadgrl.online](https://sadgrl.online/) — inspiration for hand-made, small-internet digital spaces
    
- David Shrigley, Jenny Holzer, Yoko Ono — artistic influence for one-line provocations
    
- Oblique Strategies by Brian Eno & Peter Schmidt
    
- JS libraries for generative art (e.g. p5.js for border prototyping)
    
- Sticker Mule, Moo, or other sticker printing services
    

---
## Open Questions & Considerations
- Consider adding a “curate your own QRosity” feature in the future (user-submitted quotes?)
    
- Maybe seasonal modes with different border styles or themes
    
- A mobile “QR trail” game or scavenger hunt variant
    
- Option for stickers to contain unique codes that trigger special quotes (e.g. “rare pulls”)
    
- Add ambient music or subtle generative sound?
    

---
## Project Log
### 15 Jun 2025
- Domain registered, website online
- Basic QR code experiments done, no stickers printed
- Border wobble behaviour has regressed; needs debugging
- Refresh/info buttons sometimes fail to render on first page load

### 2025-06-10
- Completed base website functionality
- Populated quote database (~700 entries)
- First test scans of prototype QR code to live site

### 2025-06-12
- Discovered visual bug in canvas wobble rendering (border lines overshooting)
- Initial testing shows button visibility issue on slow connections

### 2025-06-14
- Project documentation written
- Planning next steps around debugging and QR design
## External Files
[Any files related to the project outside of the Obsidian folder and their locations]
## Repositories
### Local Repositories
[Local repository paths and descriptions]

### GitHub Repositories
[GitHub repository URLs and descriptions]