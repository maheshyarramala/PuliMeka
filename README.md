# Heritage Board Games (8 Traditional Indian Games)

An ultra-lightweight, extensible mobile board-game platform crafted in Flutter, featuring 8 iconic ancient Indian games built entirely with **procedural vector graphics (`CustomPainter`)** to guarantee minimal app size (< 1 MB source) and maximum performance.

---

## The 8 Traditional Games

| # | Game | Native Name | Category | Players | Key Mechanics |
|---|---|---|---|---|---|
| **1** | **Puli Meka** | పులి మేక (Pulijudam) | Hunt & Strategy | 2 Players | 3 Tigers hunt vs 15 Goats trap on a 23-point grid. Minimax AI. |
| **2** | **Ashta Chamma** | అష్టా చమ్మా (Chowka Bhara) | Dice & Race | 2 or 4 Players | 4 Cowrie shells (1, 2, 3, 4, 8), 9 safe houses ('X'), inner spiral unlocked by captures. |
| **3** | **Pachisi / Chaupar** | పచీస్ (Royal Game of India) | Dice & Race | 2 or 4 Players | The legendary cruciform cross board. 4 cowries, safe castles, and the race to the central Charkoni (Heaven). |
| **4** | **Paramapadham** | పరమపదం (Vaikuntapali) | Dice & Race | 2 or 4 Players | 100-square spiritual race with Virtue Ladders and Vice Snakes to reach Moksha at square 100. |
| **5** | **Navakankari** | నవకంకరి (Nine Men's Morris / Char Bhar) | Alignment & Mills | 2 Players | 3 concentric squares (24 points). 9 coins each with Placing, Sliding, and Flying phases. Form 3-in-a-row Mills to capture. |
| **6** | **Daadi** | దాడి (Twelve Men's Morris / 12 Pawns) | Alignment & Mills | 2 Players | 12 coins each on 3 concentric squares with 4 corner diagonals (20 total mills). |
| **7** | **Pallanguzhi** | పల్లంగుళి (Ali Guli Mane / Mancala) | Pits & Sowing | 2 Players | 14 carved wooden pits with 70 tamarind seeds. Continuous sowing and empty-pit capture tactics. |
| **8** | **Three Pawns** | తీన్ గోటీ (Tapatan / 3 Men's Morris) | Alignment & Mills | 2 Players | 3 pawns each on a 3×3 diagonal grid. Placement and sliding alignment. |

---

## How the App Stays Ultra-Low Size (< 1 MB Source)

1. **Zero Bitmap Image Bloat**:
   - All 8 boards, pieces, cowrie shells, animal faces, snakes, ladders, and pits are rendered **procedurally using Flutter's `Canvas` (CustomPainter)**.
   - Adding a new game costs **under 15 KB of code** and **0 bytes of heavy PNG/JPEG assets**.
2. **Shared Engine Architecture**:
   - Shared low-latency audio effects (`place`, `move`, `select`, `capture`, `win`, `lose`).
   - Shared haptic feedback profiles.
   - Unified `GameFrame` in-game layout and `GameRegistry` catalog.

---

## How to Run

```bash
flutter pub get
flutter run
```

To build a release APK:
```bash
flutter build apk --release
```
