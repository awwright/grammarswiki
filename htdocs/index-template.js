/*
Title: Test cases
Description: Shows 6 newest records using 'date-added' or fallback to 'date', with redirect to /catalog/<id>
*/

let Catalog = [];

async function loadCatalog() {
    const indexRes = await fetch('catalog/.index.json');
    const ids = await indexRes.json();

    const casePromises = ids.map(async (id) => {
        const res = await fetch(`catalog/${id}.json`);
        return await res.json();
    });

    Catalog = await Promise.all(casePromises);
    initVueApp();
}

function initVueApp() {
    const CatalogList = {
        template: `
            <main>
                <h2>Recently Added to Catalog</h2>

                <div v-if="loading" class="loading-message">
                    <p>Loading...</p>
                </div>

                <div v-if="!loading && latestTests.length === 0" class="no-results-message">
                    <p>No test cases available.</p>
                </div>

                <div class="col-6" v-else>
                    <div
                        v-for="test in latestTests"
                        :key="test.id"
                        class="ratio-1-1"
                        @click="openTest(test)"
                        style="cursor: pointer;"
                    >
                        <span class="overlay">
                            <b>{{ test.title }}</b>
                            <p>{{ test.date }}</p>
                        </span>
                        <img :src="test.image" alt="placeholder" />
                    </div>
                </div>
            </main>
        `,
        data() {
            return {
                tests: Catalog,
                loading: false
            };
        },
        computed: {
            latestTests() {
                const getDate = (test) => new Date(test['date-added'] || test.date || 0);
                return [...this.tests]
                    .sort((a, b) => getDate(b) - getDate(a))
                    .slice(0, 6);
            }
        },
        methods: {
            openTest(test) {
                window.location.href = `/catalog/${test.id}.html`;
            }
        }
    };

    const CatalogDetail = {
        template: `
            <main>
                <div v-if="test">
                    <h2>{{ test.title }}</h2>
                    <p><strong>Date:</strong> {{ test.date }}</p>
                    <div v-html="content"></div>
                </div>
                <div v-else>
                    <p>Loading...</p>
                </div>
            </main>
        `,
        data() {
            return {
                test: null,
                content: ''
            };
        },
        async created() {
            const id = this.$route.params.id;
            const res = await fetch(`catalog/${id}.json`);
            this.test = await res.json();

            if (this.test.template) {
                const templateRes = await fetch(this.test.template);
                this.content = await templateRes.text();
            }
        }
    };

    const routes = [
        { path: '/', component: CatalogList },
        { path: '/:id.html', component: CatalogDetail }
    ];

    const router = VueRouter.createRouter({
        history: VueRouter.createWebHistory(),
        routes
    });

    const app = Vue.createApp({
        template: `<router-view></router-view>`
    });

    app.use(router);
    app.mount('#app');
}

loadCatalog();
