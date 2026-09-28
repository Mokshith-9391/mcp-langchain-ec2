# 🤖 MCP + LangChain Agent on AWS EC2

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue?logo=python&logoColor=white)](https://python.org)
[![LangChain](https://img.shields.io/badge/LangChain-1.4%2B-green?logo=chainlink&logoColor=white)](https://python.langchain.com)
[![MCP](https://img.shields.io/badge/MCP-1.30%2B-purple)](https://modelcontextprotocol.io)
[![AWS](https://img.shields.io/badge/AWS-EC2-orange?logo=amazonaws&logoColor=white)](https://aws.amazon.com/ec2/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

*Cloud Soft Solutions — APEX / NEXUS Lab*

> A LangChain agent that talks to **three MCP (Model Context Protocol) servers** — Weather, Jira and EC2 — all deployed on a single EC2 instance. The LLM never calls APIs directly; it reads each tool's name + docstring, decides which tool to use, and the MCP server does the real work.

---

## 📐 Architecture

```
                      ┌──────────────────── EC2 instance (Ubuntu 24.04) ─────────────────────┐
                      │                                                                       │
  You (SSH) ────────▶ │  agent/agent.py  (LangChain create_agent + LLM)                       │
                      │        │  MultiServerMCPClient (Streamable HTTP)                      │
                      │        ├──▶ :8001/mcp  weather_server.py ──▶ Open-Meteo API (no key)  │
                      │        ├──▶ :8002/mcp  jira_server.py    ──▶ Jira Cloud REST API      │
                      │        └──▶ :8003/mcp  ec2_server.py     ──▶ AWS EC2 API (IAM role)   │
                      └───────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
mcp-langchain-ec2/
├── README.md
├── requirements.txt
├── .env.example                 # copy to .env and fill in
├── servers/
│   ├── weather_server.py        # 2 tools  – Open-Meteo, free
│   ├── jira_server.py           # 5 tools  – Jira Cloud
│   └── ec2_server.py            # 5 tools  – boto3 (start/stop disabled by default)
├── agent/
│   └── agent.py                 # LangChain agent (interactive chat)
├── scripts/
│   ├── test_servers.py          # test servers WITHOUT an LLM
│   ├── start_servers.sh         # dev: run servers in background
│   └── stop_servers.sh
├── deploy/
│   ├── setup_ec2.sh             # one-command EC2 setup (systemd)
│   ├── systemd/                 # mcp-weather / mcp-jira / mcp-ec2 services
│   └── iam/                     # IAM policies + create_role.sh
└── logs/
```

### 🔧 Tools Available to the Agent

| Server  | Port | Tools |
|---------|------|-------|
| Weather | 8001 | `get_current_weather`, `get_forecast` |
| Jira    | 8002 | `list_projects`, `search_issues`, `get_issue`, `create_issue`, `add_comment` |
| EC2     | 8003 | `list_instances`, `describe_instance`, `get_instance_summary`, `start_instance`\*, `stop_instance`\* |

\* Only work when `EC2_ALLOW_WRITE=true`.

---

## ⚙️ Prerequisites

| Requirement | Details |
|-------------|---------|
| **AWS Account** | With permissions to launch EC2 instances and create IAM roles |
| **LLM API Key** | **Anthropic** (`ANTHROPIC_API_KEY`) or **OpenAI** (`OPENAI_API_KEY`) |
| **Python** | 3.10+ |
| **Jira Cloud** *(optional)* | Site URL + API token → [Create token here](https://id.atlassian.com/manage-profile/security/api-tokens) |

---

## 🚀 Deploy on EC2 — Step by Step

### Step 1: Create the IAM Role

This lets the EC2 server read instances without storing access keys.

**Console way:** IAM → Roles → Create role → Trusted entity: *AWS service → EC2* → Next →
Create inline policy → JSON → paste `deploy/iam/ec2-readonly-policy.json` → name the role `mcp-ec2-agent-role`.

**CLI way** (from your laptop or AWS CloudShell):

```bash
bash deploy/iam/create_role.sh                # read-only
bash deploy/iam/create_role.sh --with-write   # + start/stop (only instances tagged MCPManaged=true)
```

### Step 2: Launch the Instance

| Setting | Value |
|---------|-------|
| AMI | Ubuntu Server 24.04 LTS |
| Type | `t3.small` (t3.micro works but is tight) |
| Key pair | yours |
| Security group | **Inbound: SSH (22) from My IP only.** No other ports needed. |
| IAM instance profile | `mcp-ec2-agent-role` (Advanced details) |

> [!NOTE]
> The MCP servers listen on `127.0.0.1`, so they are **not exposed to the internet**. Only the agent on the same machine can reach them.

### Step 3: Copy the Project to the Instance

```bash
# from your laptop
scp -i mykey.pem mcp-langchain-ec2.zip ubuntu@<EC2_PUBLIC_IP>:~
ssh -i mykey.pem ubuntu@<EC2_PUBLIC_IP>

# on the instance
sudo apt-get install -y unzip
unzip mcp-langchain-ec2.zip && cd mcp-langchain-ec2
```

### Step 4: Run the Setup Script

```bash
bash deploy/setup_ec2.sh
```

This installs Python, creates `.venv`, installs packages, creates `.env`, and starts the 3 servers as **systemd services** (they auto-restart and survive reboots).

### Step 5: Add Your Keys

```bash
nano .env
```

Fill in at least `LLM_MODEL` + its API key. Add `JIRA_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN` for Jira. Then:

```bash
sudo systemctl restart mcp-weather mcp-jira mcp-ec2
```

### Step 6: Test the Servers (No LLM Needed)

```bash
.venv/bin/python scripts/test_servers.py
```

Expected: `3/3 servers reachable` with real weather data, your Jira projects, and your EC2 summary.

### Step 7: Talk to the Agent 🎉

```bash
.venv/bin/python agent/agent.py
```

---

## 💬 Example Prompts

```
What's the weather in Hyderabad right now?
Give me a 5-day forecast for Bengaluru.
List my Jira projects.
Show open bugs in project DEMO.
Create a Task in DEMO titled "Patch web servers" with description "Apply September security updates".
Add a comment to DEMO-3 saying "Started work".
How many EC2 instances do I have, and what types?
List running instances and describe the first one.
Will it rain in Mumbai tomorrow? If yes, create a Jira task in DEMO to reschedule the outdoor drill.
```

> [!TIP]
> The last prompt makes the agent **chain two MCP servers** in one answer. Watch the `🔧 calling ...` lines to see its reasoning.

**One-shot mode:**

```bash
.venv/bin/python agent/agent.py "list my running instances"
```

---

## 🛠️ Useful Commands

| Task | Command |
|------|---------|
| Service status | `systemctl status mcp-weather mcp-jira mcp-ec2` |
| Live logs | `journalctl -u mcp-jira -f` |
| Restart after editing code/.env | `sudo systemctl restart mcp-weather mcp-jira mcp-ec2` |
| Stop everything | `sudo systemctl stop mcp-weather mcp-jira mcp-ec2` |
| Local dev (no systemd) | `./scripts/start_servers.sh` / `./scripts/stop_servers.sh` |

---

## 🔒 Security

This project follows security best practices:

- **Localhost-only servers** — MCP servers bind to `127.0.0.1`, never exposed to the internet
- **IAM roles over access keys** — EC2 server uses the instance's IAM role; no credentials in code or `.env`
- **`.env` is git-ignored** — secrets never committed; file is `chmod 600` on the server
- **Write actions off by default** — `EC2_ALLOW_WRITE=false` by default; start/stop limited to instances tagged `MCPManaged=true`
- **Minimal permissions** — IAM policies follow least-privilege principle

---

## ❓ Troubleshooting

| Problem | Fix |
|---------|-----|
| `❌ not reachable` in agent | `systemctl status mcp-<name>`; check logs with `journalctl -u mcp-<name> -n 50` |
| `No AWS credentials found` | IAM role not attached → EC2 console → Actions → Security → Modify IAM role |
| `AWS error UnauthorizedOperation` | Role is missing a permission — compare with `deploy/iam/*.json` |
| `Jira API error 401` | Wrong email or token. Token belongs to the email's Atlassian account |
| `Jira API error 400` on create | Issue type name doesn't exist in that project (try "Task" or "Bug") |
| LLM auth error | Check `LLM_MODEL` prefix matches the key you set (`anthropic:` ↔ `ANTHROPIC_API_KEY`) |
| Start/stop refused | Set `EC2_ALLOW_WRITE=true`, restart `mcp-ec2`, and tag the target instance `MCPManaged=true` |

---

## 📖 How It Works (Read the Code in This Order)

1. **`servers/weather_server.py`** — Simplest server. `FastMCP(...)` + `@mcp.tool()` + `mcp.run(transport="streamable-http")`. That's all an MCP server is.
2. **`servers/jira_server.py`** — Same pattern + authentication + write actions.
3. **`servers/ec2_server.py`** — boto3 + IAM role + a safety switch for dangerous actions.
4. **`agent/agent.py`** — `MultiServerMCPClient` turns MCP tools into LangChain tools; `create_agent(model, tools)` gives the LLM the ability to use them.

---

## 🚧 Next Steps

- **Add your own server:** copy `weather_server.py`, change the tools, add it to `MCP_SERVERS` in `agent.py`
- **Build a UI:** put a FastAPI or Streamlit UI in front of the agent
- **Scale:** expose servers to other machines behind an ALB + authentication
- **Containerise:** package each server with Docker / deploy on EKS

---

## 🤝 Contributing

Contributions are welcome! Feel free to:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Mokshith Reddy** — [Cloud Soft Solutions](https://github.com/Mokshith-9391)

---

<p align="center">
  Made with ❤️ for the APEX / NEXUS Lab
</p>
