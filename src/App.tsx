/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React from 'react';
import { Download, Github, Smartphone, CheckCircle2 } from 'lucide-react';

export default function App() {
  return (
    <div className="min-h-screen bg-neutral-900 text-white p-8 font-sans">
      <div className="max-w-3xl mx-auto space-y-8">
        <div className="text-center space-y-4">
          <div className="w-20 h-20 bg-blue-500 rounded-3xl mx-auto flex items-center justify-center shadow-lg shadow-blue-500/20">
            <Smartphone className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-4xl font-bold tracking-tight">DiasOrganize</h1>
          <p className="text-neutral-400 text-lg">Seu projeto Flutter foi gerado com sucesso!</p>
        </div>

        <div className="bg-neutral-800 rounded-2xl p-6 border border-neutral-700/50 space-y-6">
          <div className="flex items-center space-x-3 text-green-400 border-b border-neutral-700 pb-4">
            <CheckCircle2 className="w-6 h-6" />
            <h2 className="text-xl font-medium">Arquivos Gerados</h2>
          </div>
          
          <ul className="space-y-4 text-neutral-300">
            <li className="flex items-start">
              <span className="w-2 h-2 rounded-full bg-blue-500 mt-2 mr-3" />
              <div>
                <strong className="text-white block">Código Flutter (Dart)</strong>
                <span>Toda a lógica, telas e banco de dados SQLite foram implementados na pasta <code>lib/</code>.</span>
              </div>
            </li>
            <li className="flex items-start">
              <span className="w-2 h-2 rounded-full bg-blue-500 mt-2 mr-3" />
              <div>
                <strong className="text-white block">GitHub Actions</strong>
                <span>Workflow pronto em <code>.github/workflows/build-apk.yml</code> para gerar o APK automaticamente a cada commit.</span>
              </div>
            </li>
            <li className="flex items-start">
              <span className="w-2 h-2 rounded-full bg-blue-500 mt-2 mr-3" />
              <div>
                <strong className="text-white block">Instruções Prontas</strong>
                <span>O arquivo <code>README.md</code> contém todos os passos detalhados.</span>
              </div>
            </li>
          </ul>
        </div>

        <div className="bg-blue-500/10 rounded-2xl p-6 border border-blue-500/20">
          <h3 className="text-lg font-medium text-blue-400 mb-4 flex items-center">
            <Download className="w-5 h-5 mr-2" />
            Como baixar e compilar o APK?
          </h3>
          <ol className="list-decimal list-inside space-y-3 text-blue-100/80">
            <li>Clique no menu de engrenagem no painel do AI Studio.</li>
            <li>Selecione <strong>Export to GitHub</strong> ou <strong>Export to ZIP</strong>.</li>
            <li>Se usar o GitHub, assim que o repositório for criado, a aba <strong>Actions</strong> já começará a compilar seu aplicativo!</li>
            <li>Quando finalizar, o APK estará disponível como Artifact para download.</li>
          </ol>
        </div>
      </div>
    </div>
  );
}
