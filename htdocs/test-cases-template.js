/*
Title: Test Cases
Description: Test case items for Grammars & Formats, with dynamic filtering and template rendering.
*/
let catalogItems = [];

async function loadcatalogItems() {
    const indexRes = await fetch('test-cases/.index.json');
    const ids = await indexRes.json();

    const casePromises = ids.map(async (id) => {
        const res = await fetch(`test-cases/${id}.json`);
        return await res.json();
    });

    catalogItems = await Promise.all(casePromises);
    initVueApp();
}

function initVueApp() {
    const TestCasesList = {
        template: `
            <main>
                <div class="container-auto col-5" style="margin: 1em 0em;">
                    <select v-model="sortBy" class="sort-select">
                        <option value="date-desc">Date Desc</option>
                        <option value="date-asc">Date Asc</option>
                        <option value="title">Title</option>
                        <option value="code">Code</option>
                    </select>
                </div>

                <div v-if="loading" class="loading-message">
                    <p>Loading...</p>
                </div>

                <div v-if="!loading && sortedTests.length === 0" class="no-results-message">
                    <p>Nothing was found matching your criteria.</p>
                </div>

                <div class="col-4" v-else>
                    <router-link
                        v-for="test in paginatedTests"
                        :key="test.id"
                        :to="'/test-cases/' + test.id + '.html'"
                        class="ratio-1-1"
                    >
                        <span class="overlay">
                            <p>{{ test.date }}</p>
                            <h4>{{ test.title }}</h4>
                            <p>{{ test.description }}</p>
                        </span>
                        <img :src="test.image" alt="placeholder" />
                    </router-link>
                </div>

                <div
                    class="pagination-controls container-auto col-5 h-align--flex"
                    style="margin-top: 1em;"
                    v-if="sortedTests.length > 0"
                >
                    <button v-if="page > 1" class="button-pagination button--solid" @click="goToPage(1)">First</button>
                    <button v-if="page > 1" class="button-pagination button--solid" @click="prevPage">Prev</button>
                    <button
                        v-for="p in pageNumbers"
                        :key="p"
                        class="button-pagination button--solid"
                        :class="{ active: p === page }"
                        @click="goToPage(p)"
                    >
                        {{ p }}
                    </button>
                    <button v-if="page < totalPages" class="button-pagination button--solid" @click="nextPage">Next</button>
                    <button v-if="page < totalPages" class="button-pagination button--solid" @click="goToPage(totalPages)">Last</button>
                </div>
            </main>
        `,
        data() {
            return {
                tests: catalogItems,
                perPage: 12,
                loading: false,
                sortBy: this.$route.query.sortBy || 'date-desc',
            };
        },
        watch: {
            '$route.query.sortBy'(newSort) {
                if (newSort && newSort !== this.sortBy) {
                    this.sortBy = newSort;
                }
            },
            sortBy(newVal) {
                this.updateQuery({ sortBy: newVal });
            },
            '$route.query.page': {
                immediate: true,
                handler(newPage) {
                    const pageNum = parseInt(newPage) || 1;
                    if (pageNum !== this.page) {
                        this.page = pageNum;
                    }
                }
            },
            '$route.query': {
                immediate: true,
                handler(newQuery, oldQuery) {
                    const filterKeys = ['search', 'standard', 'compliant-code', 'sortBy'];
                    const changed = filterKeys.some(key => newQuery[key] !== oldQuery?.[key]);
                    if (changed && this.page !== 1) {
                        this.page = 1;
                    }
                }
            }
        },
        computed: {
            page: {
                get() {
                    return parseInt(this.$route.query.page) || 1;
                },
                set(value) {
                    this.$router.push({ path: '/test-cases.html', query: { ...this.$route.query, page: value } });
                }
            },
            filteredTests() {
                const standard = (this.$route.query['standard'] || '').trim().toLowerCase();
                const code = (this.$route.query['compliant-code'] || '').trim().toLowerCase();
                const title = (this.$route.query['search'] || '').trim().toLowerCase();

                if (!standard && !code && !title) return this.tests;

                return this.tests.filter(test => {
                    const compliance = test['compliance'] || {};
                    const normalizedCompliance = {};
                    for (const key in compliance) {
                        normalizedCompliance[key.toLowerCase()] = (compliance[key] || []).map(v => v.toLowerCase());
                    }

                    const titleMatch = title ? test.title.toLowerCase().includes(title) : true;
                    const standardMatch = standard ? (standard in normalizedCompliance) : true;

                    let codeMatch = true;
                    if (code) {
                        if (standard && normalizedCompliance[standard]) {
                            codeMatch = normalizedCompliance[standard].some(val => val.includes(code));
                        } else if (!standard) {
                            codeMatch = Object.values(normalizedCompliance).some(arr =>
                                arr.some(val => val.includes(code))
                            );
                        } else {
                            codeMatch = false;
                        }
                    }

                    return titleMatch && standardMatch && codeMatch;
                });
            },
            sortedTests() {
                const sorted = [...this.filteredTests];
                switch (this.sortBy) {
                    case 'date-asc':
                        return sorted.sort((a, b) => new Date(a.date) - new Date(b.date));
                    case 'date-desc':
                        return sorted.sort((a, b) => new Date(b.date) - new Date(a.date));
                    case 'title':
                        return sorted.sort((a, b) => a.title.localeCompare(b.title));
                    case 'code':
                        return sorted.sort((a, b) => getFirstCode(a).localeCompare(getFirstCode(b)));
                    default:
                        return sorted;
                }
            },
            paginatedTests() {
                const start = (this.page - 1) * this.perPage;
                return this.sortedTests.slice(start, start + this.perPage);
            },
            totalPages() {
                return Math.max(1, Math.ceil(this.sortedTests.length / this.perPage));
            },
            pageNumbers() {
                const range = [];
                const delta = 2;
                const start = Math.max(1, this.page - delta);
                const end = Math.min(this.totalPages, this.page + delta);
                for (let i = start; i <= end; i++) range.push(i);
                return range;
            }
        },
        methods: {
            updateQuery(updates) {
                const query = { ...this.$route.query, ...updates };
                for (const key in query) {
                    if (query[key] === '') delete query[key];
                }
                this.$router.push({ path: '/test-cases.html', query });
            },
            nextPage() {
                if (this.page < this.totalPages) this.page += 1;
            },
            prevPage() {
                if (this.page > 1) this.page -= 1;
            },
            goToPage(n) {
                if (n >= 1 && n <= this.totalPages) this.page = n;
            }
        }
    };

    function getFirstCode(test) {
        const compliance = test['compliance'] || {};
        const codes = Object.values(compliance).flat();
        return codes.length > 0 ? codes[0] : '';
    }

    const TestCasesTemplateRender = {
        template: `
            <main v-if="test">
                <h2>Test Case / {{ test.title }}</h2>
                <p><strong>Date:</strong> {{ test.date }}</p>
                <div v-html="test.content"></div>
                <router-link to="/test-cases.html">← Back</router-link>
            </main>
            <main v-else-if="loaded">
                <p>Test case not found.</p>
                <router-link to="/test-cases.html">← Back</router-link>
            </main>
            <main v-else>
                <p>Loading...</p>
            </main>
        `,
        data() {
            return { test: null, loaded: false };
        },
        async created() {
            const id = this.$route.params.id;
            const test = catalogItems.find(t => t.id === id);

            if (!test) {
                this.loaded = true;
                return;
            }

            if (test.template) {
                const res = await fetch(test.template);
                const html = await res.text();
                this.test = { ...test, content: html };
            } else {
                this.test = test;
            }

            this.loaded = true;
        }
    };

    const FilterBar = {
        template: `
            <section>
                <h2>Test Cases</h2>
                <form class="filter-menu--detailed-search" @submit.prevent @reset.prevent="clearFilters">
                    <h3>Grammar & Format Quick Search</h3>
                    <div class="filter-group">
                        <div>
                            <label for="standard">Standard</label>
                            <select id="standard" v-model="standard">
                                <option value="">Any</option>
                                <option value="RFC">RFC</option>
                                <option value="ISO">ISO</option>
                            </select>
                        </div>
                        <div>
                            <label for="compliant-code">Compliant Code</label>
                            <input id="compliant-code" type="text" v-model="code" />
                        </div>
                        <div>
                            <label for="search">Search by Title</label>
                            <input id="search" type="text" v-model="search" />
                        </div>
                    </div>
                    <div class="h-align--flex--right">
                        <button class="button button--solid" type="reset">Reset</button>
                    </div>
                </form>
            </section>
        `,
        computed: {
            standard: {
                get() {
                    return this.$route.query.standard || '';
                },
                set(value) {
                    this.updateQuery({ standard: value });
                }
            },
            code: {
                get() {
                    return this.$route.query['compliant-code'] || '';
                },
                set(value) {
                    this.updateQuery({ 'compliant-code': value });
                }
            },
            search: {
                get() {
                    return this.$route.query.search || '';
                },
                set(value) {
                    this.updateQuery({ search: value });
                }
            }
        },
        methods: {
            updateQuery(updates) {
                const query = { ...this.$route.query, ...updates, page: 1 };
                for (const key in query) {
                    if (query[key] === '') delete query[key];
                }
                this.$router.push({ path: '/test-cases.html', query });
            },
            clearFilters() {
                this.$router.push({ path: '/test-cases.html', query: {} });
            }
        }
    };

    const routes = [
        { path: '/test-cases.html', component: TestCasesList },
        { path: '/test-cases/:id.html', component: TestCasesTemplateRender }
    ];

    const router = VueRouter.createRouter({
        history: VueRouter.createWebHistory('/'),
        routes
    });

    const app = Vue.createApp({
        components: { FilterBar },
        template: `
            <FilterBar v-if="$route.matched.some(m => m.path === '/test-cases.html')" />
            <router-view></router-view>
        `
    });

    app.use(router);
    app.mount('#app');
}

(async function () {
    await loadcatalogItems();
})();
