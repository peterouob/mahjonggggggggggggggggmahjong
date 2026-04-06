# MahJoin Web Frontend

React + TypeScript (Vite) client for the Mahjong matchmaking system.

## Development

1. Install dependencies:

```bash
npm install
```

2. Create env file:

```bash
cp .env.example .env
```

3. Start dev server:

```bash
npm run dev
```

## Environment Variables

`VITE_MOCK_MODE`
- `true`: Use in-browser mock data only.
- `false`: Call real backend APIs.

`VITE_API_BASE_URL`
- Backend HTTP base, default: `http://168.138.210.65:8080`

`VITE_WS_BASE_URL`
- Backend WebSocket base, default inferred from `VITE_API_BASE_URL`

Example:

```env
VITE_MOCK_MODE=false
VITE_API_BASE_URL=http://168.138.210.65:8080
VITE_WS_BASE_URL=ws://168.138.210.65:8080
```

## Scripts

```bash
npm run dev
npm run build
npm run lint
npm run preview
```
