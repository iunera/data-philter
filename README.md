# Data Philter

**Data Philter** is designed and developed by the [Apache Druid experts](https://www.iunera.com/apache-druid-ai-consulting-europe/) at [iunera](https://www.iunera.com) to simplify your interaction with Apache Druid. Running completely locally, this AI-powered gateway allows users to choose between Ollama or OpenAI models. It abstracts away the complexity of [Apache Druid](https://druid.apache.org/), making it an ideal tool for data scientists, site reliability engineers, and data engineers. By default, the connection to Apache Druid is established in "readonly mode" via the [Apache Druid MCP Server](https://github.com/iunera/druid-mcp-server), ensuring data safety. Data Philter empowers you to analyze data using simple, natural language, turning complex data exploration into an intuitive conversation. Stop writing arduous queries and start unlocking insights with ease. It leverages the robust power of the [Apache Druid MCP Server](https://github.com/iunera/druid-mcp-server) to provide a seamless and intelligent interface to your data. Future enhancements will include support for additional databases.

**Please note:** Data Philter is currently in an early development stage. While functional, it is actively being improved, and features may evolve rapidly. We welcome feedback and contributions!

With its "Local-First" architecture, data-philter ensures your sensitive data always remains secure within your own infrastructure, giving you full control and peace of mind. Connect to a growing number of databases, starting with Apache Druid, and create a unified, powerful data landscape. The intuitive user interface, powered by the MCP Server, makes data exploration feel as natural as a conversation, yet delivers the deep insights you need. Accelerate your decision-making processes, uncover the hidden potential in your data, and gain a competitive edge.

## Prerequisites

To get started with data-philter, you'll need:

- [Docker](https://www.docker.com) and Docker Compose installed.
- Access to an existing Apache Druid cluster (Router URL and credentials). You will provide these via druid.env in the installer.
  - If you don't have an existing cluster, you can use the [Development Druid installation](#development-druid-installation).

## Quick Start

![Data Philter Installation GIF](assets/images/dataphilterinstall.gif)


### Automatic Installation

#### macOS / Linux

```sh
curl -sL https://raw.githubusercontent.com/iunera/data-philter/main/install.sh | sh
```

#### Windows

```shell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/iunera/data-philter/main/install.ps1' | Select-Object -ExpandProperty Content | Invoke-Expression"
```

To update Data Philter to a newer version, simply re-run the appropriate installer script (macOS/Linux or Windows).

### Manual Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/iunera/data-philter.git
    cd data-philter
    ```
2.  **Configure your environment:**
    - Configure the `druid.env` file with the access details for your Druid Cluster.
3.  **Start the services:**
    ```bash
    docker compose up -d
    ```
4.  **Access the application:**
    - Open your web browser and navigate to http://localhost:4000. No login is required.

**Note**: Docker Images can be found here:
* [philter](https://hub.docker.com/r/iunera/philter)
* [druid-mcp-server](https://hub.docker.com/r/iunera/druid-mcp-server)

## Key Features
*   **Natural Language Querying:** Ask questions in plain English and get results from your database.
*   **Local-First Architecture:** Runs completely locally to keep your data secure.
*   **Easy Setup:** Get up and running quickly with our Docker-based setup.
*   **Apache Druid Support:** The first supported database is Apache Druid, with more to come.
*   **Powered by MCP Server:** Utilizes the robust and extensible [MCP Server](https://github.com/iunera/druid-mcp-server) for AI-driven data interaction.
*   **Flexible AI Model Support:** Supports local Ollama models (e.g., `iunera/aura-m`, `iunera/aura-l`) and OpenAI.
    *   `iunera/aura-m`: [https://ollama.com/iunera/aura-m](https://ollama.com/iunera/aura-m)
    *   `iunera/aura-l`: [https://ollama.com/iunera/aura-l](https://ollama.com/iunera/aura-l)
*   **Safe by Default:** Establishes a "readonly" connection to Apache Druid to prevent accidental data changes.

## Configuration 

### Apache Druid MCP Server

The `druid.env` file contains the settings for connecting the [druid-mcp-server](https://github.com/iunera/druid-mcp-server) to your Apache Druid cluster. Here is a description of each variable:

*   `DRUID_AUTH_USERNAME`: The username for authenticating with your Druid cluster.
*   `DRUID_AUTH_PASSWORD`: The password for authenticating with your Druid cluster.
*   `DRUID_ROUTER_URL`: The URL of your Druid router (e.g., `https://druid.example.com`).
*   `DRUID_SSL_ENABLED`: Set to `true` to enable SSL/TLS for the connection to Druid, or `false` to disable it.
*   `DRUID_EXTENSION_DRUID_BASIC_SECURITY_ENABLED`: Set to `true` if your Druid cluster uses the basic security extension.
*   `DRUID_MCP_SECURITY_OAUTH2_ENABLED`: Set to `true` to enable OAuth2 security for the MCP server.
*   `DRUID_MCP_READONLY_ENABLED`: Set to `true` to enable read-only mode, which prevents any changes to your Druid cluster. By default, the server runs in read-only mode to prevent accidental changes to your Druid cluster.

Make sure to customize these settings to match your Druid environment.

## App

The `data-philter` application can be configured using the `app.env` file. One of the key settings is `IUNERA_MODEL_TYPE`, which allows you to choose the AI model you want to use. It specifies the AI model to be used by the application, based on the Aura model tier system. Each tier is fine-tuned for specific use cases, from complex reasoning to simple pattern-matching.

There are four modes available:

*   **`ollama-m` (Medium Tier) The Reasoning Workhorse:**
    *   This mode uses the `iunera/aura-m` model (based on `granite:7b-a1b-h`, 7B parameters).
    *   It is your primary "workhorse" model for complex, multi-step tasks and conversations that require chat history context.
    *   It requires a GPU-based system or a Macbook with an M-series chip and at least 8GB of memory.

*   **`ollama-l` (Large Model):**
    *   This mode uses the `iunera/aura-l` model, which is based on the `phi4:14b` model.
    *   It is a more powerful model with advanced reasoning capabilities, recommended for complex queries and production environments.
    *   It requires a GPU-based system or a Macbook with an M-series chip and at least 16GB of memory.

*   **`ollama-xl` (Extra Large Model):**
    *   Uses the `gpt-oss:20b` model.
    *   Recommended for heavy workloads and advanced reasoning on capable hardware.
    *   Recommended on a Macbook with an Apple M‑series chip and at least 64GB of unified memory (or strong GPU setup).

*   **`openai` (OpenAI Model):**
    *   This mode uses the OpenAI API to access their models.
    *   You must provide your OpenAI API key in the `SPRING_AI_OPENAI_API_KEY` variable in the `app.env` file.

When using one of the `ollama` models, you can also configure the `SPRING_AI_OLLAMA_BASE_URL` to point to your Ollama server instance. By default, it is set to `http://host.docker.internal:11434`.

To change the model, simply edit the `IUNERA_MODEL_TYPE` variable in the `app.env` file:

```bash
IUNERA_MODEL_TYPE=ollama-m # or ollama-l, ollama-xl, or openai
```

## Usage

Once the services are running, you can start querying your Apache Druid database using natural language through the MCP Server interface.

## Development Druid installation
For development and testing, a complete local Apache Druid cluster can be installed using the [druid-local-cluster-installer](https://github.com/iunera/druid-local-cluster-installer).
This setup is designed to work seamlessly with Data Philter.

### Quick Installation (macOS / Linux)
```bash
curl -sL https://raw.githubusercontent.com/iunera/druid-local-cluster-installer/main/install.sh | sh
```

### Quick Installation (Windows)
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/iunera/druid-local-cluster-installer/main/install.ps1' | Select-Object -ExpandProperty Content | Invoke-Expression"
```

The installer will set up a complete Druid cluster and open the Druid console at `http://localhost:8888`. The default credentials are `admin`/`password`.

## Uninstall

For instructions on how to uninstall data-philter and its components, please refer to the [uninstall.md](docs/uninstall.md) guide.

## Roadmap

We are actively working on expanding data-philter to support more databases and LLMs. Our current roadmap includes:


- **Advanced Exporting UI**: Export your results as markdown.
- **Canvas Feature**: A canvas for data exploration and visualization.
- **Clickhouse Integration**: Integration of Clickhouse as a supported database.
- **Gemini Integration**: Integration of Gemini as a supported LLM.
- **Claude Integration**: Integration of Claude as a supported LLM.
- **Enhanced Query Capabilities**: Improving the natural language processing capabilities for more complex queries.

## Contributing

We welcome contributions! If you would like to contribute, please feel free to create a pull request. Please see our contributing guidelines for more information.

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

---

## About iunera

iunera specializes in:
- **AI-Powered Analytics**: Cutting-edge artificial intelligence solutions for data analysis
- **Enterprise Data Platforms**: Scalable data infrastructure and analytics platforms (Druid, Flink, Kubernetes, Kafka, Spring)
- **Model Context Protocol (MCP) Solutions**: Advanced MCP server implementations for various data systems
- **Custom AI Development**: Tailored AI solutions for enterprise needs

As veterans in Apache Druid iunera deployed and maintained a large number of solutions based on [Apache Druid](https://druid.apache.org/) in productive enterprise grade scenarios.

### Need Expert Apache Druid Consulting?

**Maximize your return on data** with professional Druid implementation and optimization services. From architecture design to performance tuning and AI integration, our experts help you navigate Druid's complexity and unlock its full potential.

**[Get Expert Druid Consulting →](https://www.iunera.com/apache-druid-ai-consulting-europe/)**


### Need Enterprise MCP Server / AI or LLM Development Consulting?

**ENTERPRISE AI INTEGRATION & CUSTOM MCP (MODEL CONTEXT PROTOCOL) SERVER DEVELOPMENT**

Iunera specializes in developing production-grade AI agents and enterprise-grade LLM solutions, helping businesses move beyond generic AI chatbots. They build secure, scalable, and future-ready AI infrastructure, underpinned by the Model Context Protocol (MCP), to connect proprietary data, legacy systems, and external APIs to advanced AI models.

**[Get Enterprise MCP Server Development Consulting →](https://www.iunera.com/enterprise-mcp-server-development/)**

For more information about our services and solutions, visit [www.iunera.com](https://www.iunera.com).

### Contact & Support

Need help? Let us know!

- **Website**: [https://www.iunera.com](https://www.iunera.com)
- **Professional Services**: Contact us through [email](mailto:consulting@iunera.com?subject=Druid%20MCP%20Server%20inquiry) for [Apache Druid enterprise consulting, support and custom development](https://www.iunera.com/apache-druid-ai-consulting-europe/)
- **Open Source**: This project is open source and community contributions are welcome

---

*© 2025 [iunera](https://www.iunera.com). Licensed under the Apache License 2.0.*

