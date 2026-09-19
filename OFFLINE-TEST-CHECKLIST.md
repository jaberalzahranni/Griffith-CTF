# Offline Test Checklist

- [ ] Docker starts while internet is disconnected
- [ ] `docker compose -p ctfd up -d --no-build` succeeds
- [ ] `http://localhost` opens CTFd
- [ ] A test user/team can register/login
- [ ] Challenge page loads
- [ ] Correct flag is accepted
- [ ] Scoreboard updates
- [ ] `docker compose -p ctfd down` stops services
- [ ] Restart works while still offline
- [ ] Accounts/challenges/scores persist after restart
- [ ] MariaDB is not published directly to participant network
- [ ] Redis is not published directly to participant network
- [ ] Test from a second BYOD device over the local Wi-Fi
- [ ] Record host IP and firewall requirements
