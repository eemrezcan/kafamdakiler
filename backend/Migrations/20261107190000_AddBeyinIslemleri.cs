using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class AddBeyinIslemleri : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "BeyinIslemleri",
                columns: table => new
                {
                    KullaniciId = table.Column<Guid>(type: "uuid", nullable: false),
                    Anahtar = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Parmakizi = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Durum = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    DurumKodu = table.Column<int>(type: "integer", nullable: false),
                    Cevap = table.Column<string>(type: "text", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BeyinIslemleri", x => new { x.KullaniciId, x.Anahtar });
                });

            migrationBuilder.CreateIndex(
                name: "IX_BeyinIslemleri_CreatedAt",
                table: "BeyinIslemleri",
                column: "CreatedAt");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BeyinIslemleri");
        }
    }
}
