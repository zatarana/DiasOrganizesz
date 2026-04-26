/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React from 'react';
import { Download, Github, Smartphone, CheckCircle2 } from 'lucide-react';

export default function App() {
  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 p-8 font-sans">
      <div className="max-w-3xl mx-auto space-y-8">
        <div className="text-center space-y-4">
          <div className="w-20 h-20 bg-indigo-600 rounded-3xl mx-auto flex items-center justify-center shadow-lg shadow-indigo-200">
            <Smartphone className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-4xl font-bold tracking-tight text-slate-800">DiasOrganize</h1>
          <p className="text-slate-500 text-lg">Seu projeto Flutter foi gerado com sucesso!</p>
        </div>

        <div className="bg-white rounded-3xl p-6 border border-slate-100 shadow-sm flex flex-col space-y-6">
          <div className="flex items-center space-x-3 text-emerald-600 border-b border-slate-50 pb-4">
            <CheckCircle2 className="w-6 h-6" />
            <h2 className="text-lg font-bold text-slate-800 tracking-tight">Arquivos e Telas Geradas</h2>
          </div>
          
          <ul className="space-y-4 text-slate-500 text-sm">
            <li className="flex items-start group">
              <span className="w-2 h-2 rounded-full border-2 border-indigo-200 group-hover:border-indigo-500 transition-colors mt-1.5 mr-4 flex-shrink-0" />
              <div>
                <strong className="text-slate-800 block mb-0.5">Banco de dados local e Schema</strong>
                <span>Tabelas <code className="bg-slate-100 text-slate-600 px-1.5 py-0.5 rounded font-bold text-xs">tasks</code>, <code className="bg-slate-100 text-slate-600 px-1.5 py-0.5 rounded font-bold text-xs">categories</code> e <code className="bg-slate-100 text-slate-600 px-1.5 py-0.5 rounded font-bold text-xs">settings</code> validadas no SQLite (passo 6 do PRD).</span>
              </div>
            </li>
            <li className="flex items-start group">
              <span className="w-2 h-2 rounded-full border-2 border-indigo-200 group-hover:border-indigo-500 transition-colors mt-1.5 mr-4 flex-shrink-0" />
              <div>
                <strong className="text-slate-800 block mb-0.5">Arquitetura Clean e Offline-first</strong>
                <span>Organização completa do projeto em camadas (data, domain, features), validando o passo 4 do PRD. Tendo como base banco offline via SQFLite.</span>
              </div>
            </li>
            <li className="flex items-start group">
              <span className="w-2 h-2 rounded-full border-2 border-indigo-200 group-hover:border-indigo-500 transition-colors mt-1.5 mr-4 flex-shrink-0" />
              <div>
                <strong className="text-slate-800 block mb-0.5">Código Flutter (Dart)</strong>
                <span>Toda a lógica e 8 telas principais validadas (Home, Tarefas, Calendário, Categorias, Estatísticas e Ajustes) estão implementadas em <code className="bg-slate-100 text-slate-600 px-1.5 py-0.5 rounded font-bold text-xs">lib/</code>.</span>
              </div>
            </li>
            <li className="flex items-start group">
              <span className="w-2 h-2 rounded-full border-2 border-indigo-200 group-hover:border-indigo-500 transition-colors mt-1.5 mr-4 flex-shrink-0" />
              <div>
                <strong className="text-slate-800 block mb-0.5">GitHub Actions</strong>
                <span>Workflow pronto em <code className="bg-slate-100 text-slate-600 px-1.5 py-0.5 rounded font-bold text-xs">.github/workflows/build-apk.yml</code> para gerar o APK automaticamente a cada commit.</span>
              </div>
            </li>
            <li className="flex items-start group">
              <span className="w-2 h-2 rounded-full border-2 border-indigo-200 group-hover:border-indigo-500 transition-colors mt-1.5 mr-4 flex-shrink-0" />
              <div>
                <strong className="text-slate-800 block mb-0.5">Módulo de Notificações, Configuração e Filtros implementados</strong>
                <span>Os requisitos do PRD foram revisados, integrados e validados no banco de dados SQLite.</span>
              </div>
            </li>
            <li className="flex items-start group">
              <span className="w-2 h-2 rounded-full border-2 border-indigo-200 group-hover:border-indigo-500 transition-colors mt-1.5 mr-4 flex-shrink-0" />
              <div>
                <strong className="text-slate-800 block mb-0.5">Regras de Negócio</strong>
                <span>Verificação de atraso, atualização local de tarefas e auto-cancelamento de notificações implementados (passo 7 do PRD).</span>
              </div>
            </li>
            <li className="flex items-start group">
              <span className="w-2 h-2 rounded-full border-2 border-indigo-200 group-hover:border-indigo-500 transition-colors mt-1.5 mr-4 flex-shrink-0" />
              <div>
                <strong className="text-slate-800 block mb-0.5">Critérios de Aceite</strong>
                <span>Todos os critérios do passo 11 (abrir sem crash, operações de tarefas, filtro, tema dinâmico, teste dummy local e CI via GitHub Actions) finalizados.</span>
              </div>
            </li>
            <li className="flex items-start group">
              <span className="w-2 h-2 rounded-full border-2 border-indigo-200 group-hover:border-indigo-500 transition-colors mt-1.5 mr-4 flex-shrink-0" />
              <div>
                <strong className="text-slate-800 block mb-0.5">Escopo da Versão 2.0 Aceito</strong>
                <span>Módulos de Finanças, Dívidas e Projetos mapeados. Restrições do projeto (sem integrações bancárias diretas, nuvem, etc) entendidas. Foco em base offline, local e sólida estruturado.</span>
              </div>
            </li>
            <li className="flex items-start group">
              <span className="w-2 h-2 rounded-full border-2 border-indigo-200 group-hover:border-indigo-500 transition-colors mt-1.5 mr-4 flex-shrink-0" />
              <div>
                <strong className="text-slate-800 block mb-0.5">Modelo Atualizado: FinancialTransaction</strong>
                <span>Banco de dados v4 migrado. Todos os 16 campos obrigatórios (description, paidDate, status, recurrenceType, notes, etc.) adicionados ao SQFLite, e tela de edição/criação aprimorada para dar suporte direto a 'dinheiro', 'pix', etc., mantendo regras de negócio solicitadas!</span>
              </div>
            </li>
            <li className="flex items-start group">
              <span className="w-2 h-2 rounded-full border-2 border-indigo-200 group-hover:border-indigo-500 transition-colors mt-1.5 mr-4 flex-shrink-0" />
              <div>
                <strong className="text-slate-800 block mb-0.5">Categorias e Dashboard Financeiro</strong>
                <span>Categorias Financeiras isoladas das tarefas. Tela de Finanças ajustada como dashboard unificado exibindo os totais gerais (receitas, despesas, saldo realizado, saldo previsto) baseados no mês ativo, atalhos de filtros e lista histórica.</span>
              </div>
            </li>
            <li className="flex items-start group">
              <span className="w-2 h-2 rounded-full border-2 border-indigo-200 group-hover:border-indigo-500 transition-colors mt-1.5 mr-4 flex-shrink-0" />
              <div>
                <strong className="text-slate-800 block mb-0.5">Regras Financeiras 100% Ativas</strong>
                <span>Calculos precisos do Painel: Receitas Totais, Despesas Totais, Saldo Previsto (ignora cancelamentos), Saldo Realizado (apenas transações pagas), regras de despencimento de datas. E o recurso de Replicação de Movimentações Fixas mensal integrados.</span>
              </div>
            </li>
            <li className="flex items-start group">
              <span className="w-2 h-2 rounded-full border-2 border-indigo-200 group-hover:border-indigo-500 transition-colors mt-1.5 mr-4 flex-shrink-0" />
              <div>
                <strong className="text-slate-800 block mb-0.5">Módulo de Dívidas Integrado</strong>
                <span>Dívidas cadastradas isoladamente, com capacidade de prever ou projetar automaticamente diversas parcelas em Despesas (dentro do módulo Financeiro). Resumo de pagamento acompanha todas as parcelas integradas à dívida base!</span>
              </div>
            </li>
          </ul>
        </div>

        <div className="bg-indigo-900 rounded-3xl p-6 shadow-lg border border-indigo-800 text-white">
          <h3 className="text-sm font-bold uppercase tracking-widest text-indigo-300 mb-6 flex items-center">
            <Download className="w-5 h-5 mr-3" />
            Como baixar e compilar o APK?
          </h3>
          <ol className="list-decimal list-inside space-y-4 text-indigo-200 text-sm">
            <li>Clique no menu de engrenagem no painel do AI Studio.</li>
            <li>Selecione <strong className="text-white">Export to GitHub</strong> ou <strong className="text-white">Export to ZIP</strong>.</li>
            <li>Se usar o GitHub, assim que o repositório for criado, a aba <strong className="text-white">Actions</strong> já começará a compilar seu aplicativo!</li>
            <li>Quando finalizar, o APK estará disponível como Artifact para download.</li>
          </ol>
        </div>
      </div>
    </div>
  );
}
