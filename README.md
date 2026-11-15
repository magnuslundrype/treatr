# Treatr

AI-butler til luksusvillaer. Gæsten skriver, butleren foreslår, et menneske godkender med
to tryk, og leverandøren bekræfter via et link uden login.

| Du vil                                    | Læs                                                      |
| ----------------------------------------- | -------------------------------------------------------- |
| I gang første dag                         | [docs/foerste-dag.md](docs/foerste-dag.md)               |
| Kende arbejdsgangen (én side)             | [docs/saadan-arbejder-vi.md](docs/saadan-arbejder-vi.md) |
| Vide hvordan man bidrager                 | [CONTRIBUTING.md](CONTRIBUTING.md)                       |
| Forstå arkitekturen                       | [ARCHITECTURE.md](ARCHITECTURE.md)                       |
| Se datamodellen                           | [docs/erd.md](docs/erd.md)                               |
| Se hvorfor vi valgte, som vi gjorde       | [docs/adr/](docs/adr/)                                   |
| Sætte GitHub, Linear, Vercel, Supabase op | [docs/opsaetning.md](docs/opsaetning.md)                 |
| Se planen for ugen i Spanien              | [docs/5-dages-plan.md](docs/5-dages-plan.md)             |

```bash
npm install        # afhængigheder og git-hooks
npm run check      # typecheck, lint, format, test
npm run db:test    # byg databasen fra bunden og test reglerne (kræver Docker)
npm run dev        # http://localhost:3000
```

Stak: Next.js på Vercel, Supabase (Postgres, Auth), GitHub, Linear.
